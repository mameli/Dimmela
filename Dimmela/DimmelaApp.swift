import DimmelaCore
import SwiftUI

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { model.launch() }
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

private extension DictationController.Phase {
    var symbol: String {
        switch self {
        case .idle: "waveform"
        case .recording: "record.circle"
        case .processing: "hourglass"
        }
    }
}
