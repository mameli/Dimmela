import DimmelaCore
import SwiftUI
import UserNotifications

@main
struct DimmelaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            Image(systemName: delegate.model.controller.phase.symbol)
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        MainActor.assumeIsolated { model.launch() }
    }

    /// Shows banners also while Dimmela is the active app, as right after a click in its menu:
    /// by default macOS drops them.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
}

private struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings
    @AppStorage(AppSettings.enabledModesKey) private var enabled = ""
    @AppStorage(AppSettings.defaultModeKey) private var defaultModeID = ""

    var body: some View {
        Text(status)
        if !model.accessibilityGranted {
            Button("Allow Accessibility…") { model.requestAccessibility() }
        }
        if model.microphonePermission == .denied || model.microphonePermission == .restricted {
            Button("Allow the Microphone…") { model.openMicrophoneSettings() }
        }
        Divider()
        if !model.history.entries.isEmpty {
            Menu("History") {
                ForEach(model.history.entries) { entry in
                    HistoryMenu(model: model, entry: entry, modes: AppSettings.lines(of: enabled).map(Mode.init(id:)))
                }
            }
        }
        Picker("Default Mode", selection: $defaultModeID) {
            Text("None").tag("")
            ForEach(AppSettings.lines(of: enabled).map(Mode.init(id:))) { Text($0.name).tag($0.id) }
        }
        Button("Settings…") {
            // No Dock icon: without activating, the window would stay behind the others.
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit Dimmela") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var status: String {
        switch model.speechModel.state {
        case .notLoaded: "Speech model not loaded"
        case .downloading(let percent): "Downloading the speech model… \(percent)%"
        case .preparing(firstTime: true): "Preparing the speech model (a few minutes, only once)…"
        case .preparing(firstTime: false): "Loading the speech model…"
        case .failed(let detail): "Speech model unavailable: \(detail)"
        case .ready:
            switch model.controller.phase {
            case .idle: "Ready: hold or tap fn+Space to dictate"
            case .recording: "Listening…"
            case .processing: "Transcribing…"
            }
        }
    }
}

private struct HistoryMenu: View {
    let model: AppModel
    let entry: HistoryEntry
    let modes: [Mode]

    var body: some View {
        Menu(title) {
            Button("Copy Text") { model.copy(entry.text) }
            if entry.text != entry.transcript {
                Button("Copy Transcript") { model.copy(entry.transcript) }
            }
            if !modes.isEmpty {
                Menu("Post-process Again With") {
                    ForEach(modes) { mode in
                        Button(mode.name) { model.postProcessAgain(entry, with: mode) }
                    }
                }
            }
        }
    }

    /// Time, Mode and the start of the text: "10:42 · Clean · Ciao, sto provando…".
    private var title: String {
        let time = entry.date.formatted(date: .omitted, time: .shortened)
        let start = entry.text.count > 40 ? entry.text.prefix(40) + "…" : entry.text
        return [time, entry.modeName, start].compactMap { $0 }.joined(separator: " · ")
    }
}

private extension DictationController.Phase {
    var symbol: String {
        switch self {
        case .idle: "waveform"
        case .recording: "record.circle"
        case .processing: "hourglass"
        }
    }
}
