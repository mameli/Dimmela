import AppKit
import ApplicationServices
import DimmelaCore
import Observation
import UserNotifications
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "app")

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

    init() {
        AppSettings.registerDefaults()
        controller = DictationController(boundaries: DictationBoundaries(
            startRecording: { [recorder, weak self] in
                try recorder.start { decibels in
                    Task { @MainActor in self?.controller.microphoneLoudness(decibels) }
                }
            },
            stopRecording: { [recorder] in recorder.stop() },
            findSpeech: { [speechDetector] samples in try await speechDetector.speechRange(in: samples) },
            transcribe: { [speechModel] samples in try await speechModel.transcribe(samples) },
            paste: { text in try await Paster.paste(text) },
            report: { problem in Self.show(problem) },
            defaultMode: { AppSettings.defaultMode },
            setDefaultMode: { AppSettings.defaultMode = $0 },
            enabledModes: { AppSettings.enabledModes },
            vocabulary: { AppSettings.vocabulary },
            history: history,
            chatClient: { try ChatClient.configured() }
        ))
        // Tasks started on the main actor run in the order the keys arrived.
        shortcut.onDown = { [unowned self] time in
            Task { await self.controller.shortcutDown(at: time) }
        }
        shortcut.onUp = { [unowned self] time in
            Task { await self.controller.shortcutUp(at: time) }
        }
        shortcut.onEscape = { [unowned self] in
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
        do {
            try AppSettings.createVocabularyFileIfNeeded()
        } catch {
            logger.error("Vocabulary file not created: \(error, privacy: .public)")
        }
        #if DEBUG
        if SmokeTest.runIfRequested(model: speechModel, detector: speechDetector) { return }
        #endif
        overlay = OverlayPanel(controller: controller)
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
    }

    func requestMicrophone() async {
        if microphonePermission == .notDetermined {
            _ = await MicrophoneRecorder.requestPermission()
        }
        microphonePermission = MicrophoneRecorder.permission
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
                if shortcut.start() { break }
            }
            self?.permissionPoll = nil
        }
    }

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
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

    private static func show(_ problem: DictationProblem) {
        let message = switch problem {
        case .microphoneUnavailable(let detail): "Can't record: \(detail)"
        case .transcriptionFailed(let detail): "Can't transcribe: \(detail)"
        case .pasteFailed(let detail): "Can't paste: \(detail)"
        case .postProcessingFailed(let detail): "Post-processing failed, the Transcript was pasted instead: \(detail)"
        case .postProcessingAgainFailed(let detail): "Post-processing failed: \(detail)"
        }
        logger.error("\(message, privacy: .public)")
        notify(message)
    }

    private static func notify(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Dimmela"
        content.body = message
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
