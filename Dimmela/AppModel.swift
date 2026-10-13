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
    private(set) var controller: DictationController!
    private(set) var accessibilityGranted = AXIsProcessTrusted()
    private(set) var microphonePermission = MicrophoneRecorder.permission

    @ObservationIgnored private let recorder = MicrophoneRecorder()
    @ObservationIgnored private let shortcut = ShortcutMonitor()
    @ObservationIgnored private var permissionPoll: Task<Void, Never>?
    @ObservationIgnored private var overlay: OverlayPanel?

    init() {
        controller = DictationController(boundaries: DictationBoundaries(
            startRecording: { [recorder, weak self] in
                try recorder.start { level in
                    Task { @MainActor in self?.controller.microphoneLevel(level) }
                }
            },
            stopRecording: { [recorder] in recorder.stop() },
            transcribe: { [speechModel] samples in try await speechModel.transcribe(samples) },
            paste: { text in try await Paster.paste(text) },
            report: { problem in Self.show(problem) },
            defaultMode: { AppSettings.defaultMode },
            enabledModes: { AppSettings.enabledModes },
            chatClient: { try ChatClient.configured() }
        ))
        // Tasks started on the main actor run in the order the keys arrived.
        shortcut.onDown = { [unowned self] shift, time in
            Task { await self.controller.shortcutDown(shift: shift, at: time) }
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
        shortcut.onShift = { [unowned self] isDown in controller.shiftChanged(isDown: isDown) }
    }

    func launch() {
        #if DEBUG
        if SmokeTest.runIfRequested(model: speechModel) { return }
        #endif
        overlay = OverlayPanel(controller: controller)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        Task {
            if microphonePermission == .notDetermined {
                _ = await MicrophoneRecorder.requestPermission()
                microphonePermission = MicrophoneRecorder.permission
            }
        }
        Task { try? await speechModel.prepare() }
        if !shortcut.start() {
            requestAccessibility()
        }
    }

    /// Shows the system prompt, then waits for the grant: macOS gives no callback.
    func requestAccessibility() {
        // The value of kAXTrustedCheckOptionPrompt, a C global Swift 6 refuses to read.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
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

    private static func show(_ problem: DictationProblem) {
        let message = switch problem {
        case .microphoneUnavailable(let detail): "Can't record: \(detail)"
        case .transcriptionFailed(let detail): "Can't transcribe: \(detail)"
        case .pasteFailed(let detail): "Can't paste: \(detail)"
        case .postProcessingFailed(let detail): "Post-processing failed, the Transcript was pasted instead: \(detail)"
        }
        logger.error("\(message, privacy: .public)")
        let content = UNMutableNotificationContent()
        content.title = "Dimmela"
        content.body = message
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
