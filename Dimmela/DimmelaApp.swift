import DimmelaCore
import SwiftUI

@main
struct DimmelaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            delegate.model.controller.phase.icon
        }

        Settings {
            SettingsView(model: delegate.model)
        }

        Window("Welcome to Dimmela", id: WelcomeView.windowID) {
            WelcomeView(model: delegate.model)
        }
        // The hero's green reaches the top of the window, as on dimmela.app.
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(WelcomeView.isNeededAtLaunch ? .presented : .suppressed)
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
        // Holding ⌥ copies the Transcript instead, before Post-processing.
        Button("Copy Last") {
            if let last = model.history.entries.first { model.copy(last.text) }
        }
        .disabled(model.history.entries.isEmpty)
        .modifierKeyAlternate(.option) {
            Button("Copy Last Transcript") {
                if let last = model.history.entries.first { model.copy(last.transcript) }
            }
            .disabled(model.history.entries.isEmpty)
        }
        let modes = AppSettings.lines(of: enabled).map(Mode.init(id:))
        if !model.history.entries.isEmpty, !modes.isEmpty {
            // One click when the provider failed and the Transcript was pasted instead.
            if let mode = model.lastDictationMode {
                Button("Reprocess Last (\(mode.name))") { model.postProcessLastAgain(with: mode) }
            }
            Menu("Reprocess Last With") {
                ForEach(modes) { mode in
                    Button(mode.name) { model.postProcessLastAgain(with: mode) }
                }
            }
        }
        Divider()
        if let release = model.updates.available {
            Button("Dimmela \(release.version) is available…") { model.updates.check() }
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
                Menu("Reprocess With") {
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
    var icon: Image {
        switch self {
        case .idle: Image("MenuBarIcon")
        case .recording: Image(systemName: "record.circle")
        case .processing: Image(systemName: "hourglass")
        }
    }
}
