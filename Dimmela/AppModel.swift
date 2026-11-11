import AppKit
import ApplicationServices
import DimmelaCore
import Observation
import UserNotifications

private let logger = AppLog(category: "app")

/// Wires the platform pieces to the Dictation controller and holds what the menu shows.
@MainActor
@Observable
final class AppModel {
    let speechModel = SpeechModel()
    let updates = UpdateChecker()
    @ObservationIgnored private let speechDetector = SpeechDetector()
    let history = History(directory: URL.applicationSupportDirectory.appending(path: "Dimmela/History", directoryHint: .isDirectory))
    private(set) var controller: DictationController!
    private(set) var accessibilityGranted = AXIsProcessTrusted()
    private(set) var microphonePermission = MicrophoneRecorder.permission
    private(set) var notificationsAllowed = false

    @ObservationIgnored private let recorder = MicrophoneRecorder()
    @ObservationIgnored private let shortcut = ShortcutMonitor()
    @ObservationIgnored private var permissionPoll: Task<Void, Never>?
    @ObservationIgnored private var overlay: OverlayPanel?
    @ObservationIgnored private var notificationActions: NotificationActions?

    init() {
        AppSettings.registerDefaults()
        AppSettings.migrateProviderIfNeeded()
        controller = DictationController(boundaries: DictationBoundaries(
            startRecording: { [recorder, weak self] in
                try recorder.start { decibels in
                    Task { @MainActor in self?.controller.microphoneLoudness(decibels) }
                }
            },
            stopRecording: { [recorder, weak self] in
                let samples = recorder.stop()
                let mode = self?.controller.mode?.name ?? "none"
                logger.info("Recording stopped: \(Self.seconds(samples.count)) of audio, Mode: \(mode)")
                return samples
            },
            findSpeech: { [speechDetector] samples in
                let speech = try await speechDetector.speechRange(in: samples)
                if let speech {
                    logger.info("Speech from \(Self.seconds(speech.lowerBound)) to \(Self.seconds(speech.upperBound))")
                } else {
                    logger.info("No speech found: nothing is pasted")
                }
                return speech
            },
            transcribe: { [speechModel] samples in
                let start = ContinuousClock.now
                let transcript = try await speechModel.transcribe(samples)
                logger.info("Transcribed \(Self.seconds(samples.count)) in \(Self.elapsed(since: start)): \(transcript.count) characters")
                return transcript
            },
            paste: { text in
                try await Paster.paste(text)
                logger.info("Pasted \(text.count) characters")
            },
            report: { problem in Self.show(problem) },
            defaultMode: { AppSettings.defaultMode },
            setDefaultMode: { AppSettings.defaultMode = $0 },
            enabledModes: { AppSettings.enabledModes },
            vocabulary: { AppSettings.vocabulary },
            history: history,
            chatClients: {
                AppSettings.providerProfiles.chain.map { profile in
                    NamedChatClient(name: profile.displayName) { try ChatClient.configured(profile) }
                }
            },
            recordPostProcessing: { record in
                guard AppSettings.keepsPostProcessingLog else { return }
                AppSettings.postProcessingLog.write(record.jsonLine)
            }
        ))
        // Tasks started on the main actor run in the order the keys arrived.
        shortcut.onDown = { [unowned self] time in
            if controller.phase == .idle { logger.info("Dictation started") }
            Task { await self.controller.shortcutDown(at: time) }
        }
        shortcut.onUp = { [unowned self] time in
            Task { await self.controller.shortcutUp(at: time) }
        }
        shortcut.onEscape = { [unowned self] in
            logger.info("Esc: Dictation cancelled while \(controller.phase == .recording ? "recording" : "processing")")
            Task { await self.controller.escape() }
        }
        shortcut.capturesEscape = { [unowned self] in controller.capturesEscape }
        shortcut.onDigit = { [unowned self] digit in controller.modeDigit(digit) }
        shortcut.capturesDigits = { [unowned self] in controller.capturesDigits }
        shortcut.onShift = { [unowned self] in controller.shiftPressed() }
        shortcut.onArrow = { [unowned self] offset in controller.moveModeSelection(by: offset) }
        shortcut.onReturn = { [unowned self] in controller.confirmModeList() }
        shortcut.capturesModeListKeys = { [unowned self] in controller.capturesModeListKeys }
    }

    func launch() {
        let info = Bundle.main.infoDictionary
        logger.info("Dimmela \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?")) started")
        do {
            try AppSettings.createVocabularyFileIfNeeded()
        } catch {
            logger.error("Vocabulary file not created: \(error.localizedDescription)")
        }
        #if DEBUG
        if SmokeTest.runIfRequested(model: speechModel, detector: speechDetector) { return }
        #endif
        do {
            try AppSettings.installBuiltInModes()
        } catch {
            logger.error("Built-in Modes not written: \(error.localizedDescription)")
        }
        overlay = OverlayPanel(controller: controller)
        notificationActions = NotificationActions { [weak self] in self?.postProcessLastAgain() }
        // A relaunch in the middle of a Dictation would lose it.
        updates.isBusy = { [weak self] in self?.controller.phase != .idle }
        updates.start()
        Task { try? await speechModel.prepare() }
        Task { await speechDetector.prepare() }
        Task { await refreshNotifications() }
        // On the first launch the welcome window asks for the permissions, one at a time.
        guard UserDefaults.standard.bool(forKey: AppSettings.onboardingDoneKey) else {
            startWatchingWhenAllowed()
            return
        }
        Task { await requestMicrophone() }
        Task { await requestNotificationsIfNeverAsked() }
        if !shortcut.start() {
            requestAccessibility()
        }
        logger.info("Accessibility: \(accessibilityGranted ? "granted" : "not granted")")
    }

    /// Samples at the recorder's rate, as seconds: "3.2 s".
    private nonisolated static func seconds(_ samples: Int) -> String {
        "\((Double(samples) / MicrophoneRecorder.sampleRate).formatted(logNumber.precision(.fractionLength(1)))) s"
    }

    /// Numbers in the log as in English, whatever the Mac's language: the log goes in issues.
    private nonisolated static let logNumber = FloatingPointFormatStyle<Double>(locale: Locale(identifier: "en_US_POSIX"))

    nonisolated static func elapsed(since start: ContinuousClock.Instant) -> String {
        let elapsed = (ContinuousClock.now - start).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        return "\(seconds.formatted(logNumber.precision(.fractionLength(2)))) s"
    }

    func requestMicrophone() async {
        if microphonePermission == .notDetermined {
            _ = await MicrophoneRecorder.requestPermission()
        }
        microphonePermission = MicrophoneRecorder.permission
        let state = switch microphonePermission {
        case .authorized: "allowed"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "not asked yet"
        @unknown default: "unknown"
        }
        logger.info("Microphone: \(state)")
    }

    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        await refreshNotifications()
    }

    /// After the welcome window, when macOS has forgotten the answer (notifications reset in
    /// System Settings): asked again once. A refusal is respected.
    private func requestNotificationsIfNeverAsked() async {
        guard await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined else { return }
        await requestNotifications()
    }

    /// Read again when Dimmela comes back from System Settings.
    func refreshPermissions() async {
        microphonePermission = MicrophoneRecorder.permission
        accessibilityGranted = AXIsProcessTrusted()
        await refreshNotifications()
    }

    private func refreshNotifications() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsAllowed = status == .authorized || status == .provisional
    }

    /// Shows the system prompt, then waits for the grant: macOS gives no callback.
    func requestAccessibility() {
        // The value of kAXTrustedCheckOptionPrompt, a C global Swift 6 refuses to read.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        startWatchingWhenAllowed()
    }

    /// Starts the keyboard watch now, or as soon as Accessibility is granted.
    private func startWatchingWhenAllowed() {
        if shortcut.start() {
            accessibilityGranted = true
            return
        }
        guard permissionPoll == nil else { return }
        permissionPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, AXIsProcessTrusted() else { continue }
                accessibilityGranted = true
                SettingsDragCard.shared.close()
                if shortcut.start() { break }
            }
            self?.permissionPoll = nil
        }
    }

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    /// With a card to drag Dimmela into the list: the way in when it is not listed, or when the
    /// row there is another copy of Dimmela, which macOS tells apart by its signature.
    func openAccessibilitySettings() {
        SettingsDragCard.shared.show(
            opening: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!,
            list: "Accessibility"
        )
        startWatchingWhenAllowed()
    }

    func openNotificationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Copies the result rather than pasting it: the menu has just taken the focus.
    func postProcessAgain(_ entry: HistoryEntry, with mode: Mode) {
        Task {
            guard let text = await controller.postProcessAgain(entry, with: mode) else { return }
            copy(text)
            Self.notify("\(mode.name): the new text is on the clipboard.")
        }
    }

    /// The Mode the last Dictation was Post-processed with, or the Default Mode if it was not
    /// (or that Mode is no longer enabled): what *Post-process Last Dictation Again* uses.
    var lastDictationMode: Mode? {
        guard let last = history.entries.first else { return nil }
        let enabled = AppSettings.enabledModes
        return last.mode.flatMap { mode in enabled.first { $0 == mode } } ?? AppSettings.defaultMode
    }

    /// The last Dictation Post-processed again, with `mode` or `lastDictationMode`.
    func postProcessLastAgain(with mode: Mode? = nil) {
        guard let last = history.entries.first, let mode = mode ?? lastDictationMode else { return }
        postProcessAgain(last, with: mode)
    }

    private static func show(_ problem: DictationProblem) {
        let message = switch problem {
        case .microphoneUnavailable(let detail): "Can't record: \(detail)"
        case .transcriptionFailed(let detail): "Can't transcribe: \(detail)"
        case .pasteFailed(let detail): "Can't paste: \(detail)"
        case .postProcessingFailed(let detail): "Post-processing failed, the Transcript was pasted instead: \(detail)"
        case .postProcessingAgainFailed(let detail): "Post-processing failed: \(detail)"
        case .postProcessingFellBack(let failed, let detail, let answeredBy): "\(failed) failed, \(answeredBy) answered instead: \(detail)"
        }
        logger.error(message)
        if case .postProcessingFailed = problem {
            notify(message, category: NotificationActions.postProcessingFailed)
        } else {
            notify(message)
        }
    }

    private static func notify(_ message: String, category: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = "Dimmela"
        content.body = message
        if let category { content.categoryIdentifier = category }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
