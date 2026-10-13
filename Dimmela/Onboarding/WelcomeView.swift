import AppKit
import SwiftUI

/// The window shown on the first launch: the permissions and the download to do before the first
/// Dictation, each step ticked as soon as it is done. Closed with Done; the menu reopens it with
/// *Set Up Dimmela…* until then.
struct WelcomeView: View {
    static let windowID = "welcome"

    /// Until Done is clicked once. In Debug builds `-showWelcome YES` shows it anyway.
    static var isNeededAtLaunch: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "showWelcome") { return true }
        #endif
        return !UserDefaults.standard.bool(forKey: AppSettings.onboardingDoneKey)
    }

    let model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(AppSettings.onboardingDoneKey) private var isDone = false
    @AppStorage(AppSettings.defaultModeKey) private var defaultModeID = ""

    var body: some View {
        Form {
            Section {
                Text("Hold or tap fn+Space anywhere, speak, and Dimmela pastes the text where you are typing. Everything is transcribed on this Mac. A few steps before the first Dictation:")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Text("To hear you while you dictate. The microphone is on only during a Dictation.")
                    .foregroundStyle(.secondary)
                switch model.microphonePermission {
                case .notDetermined:
                    button("Allow the Microphone") { await model.requestMicrophone() }
                case .denied, .restricted:
                    settingsLink("The microphone is not allowed.") { model.openMicrophoneSettings() }
                default:
                    EmptyView()
                }
            } header: {
                Step(number: 1, title: "Microphone", isDone: model.microphonePermission == .authorized)
            }

            Section {
                Text("To see fn+Space in every app and to paste the text. In System Settings, turn Dimmela on in the list.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.accessibilityGranted {
                    HStack {
                        Button("Allow Accessibility") { model.requestAccessibility() }
                        Button("Open System Settings") { model.openAccessibilitySettings() }
                        Spacer()
                    }
                }
            } header: {
                Step(number: 2, title: "Accessibility", isDone: model.accessibilityGranted)
            }

            Section {
                Text("To tell you when something goes wrong, for example when the Transcript is pasted because Post-processing failed.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.notificationsAllowed {
                    HStack {
                        button("Allow Notifications") { await model.requestNotifications() }
                        Button("Open System Settings") { model.openNotificationSettings() }
                        Spacer()
                    }
                }
            } header: {
                Step(number: 3, title: "Notifications", isDone: model.notificationsAllowed)
            }

            Section {
                SpeechModelStatus(model: model.speechModel)
            } header: {
                Step(number: 4, title: "Speech model", isDone: model.speechModel.state == .ready)
            }

            Section {
                Text("Optional: an LLM can rewrite each Dictation with your prompts and skills (Modes). Add a provider key and a folder of Modes in Settings.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open Settings…") {
                        NSApplication.shared.activate()
                        openSettings()
                    }
                    Spacer()
                }
            } header: {
                Step(number: 5, title: "Post-processing", isDone: !defaultModeID.isEmpty)
            }

            Section {
                HStack {
                    Image("MenuBarIcon").renderingMode(.template)
                    Text("Dimmela lives in the menu bar.")
                    Spacer()
                    Button("Done") {
                        isDone = true
                        dismissWindow(id: Self.windowID)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 680)
        // No Dock icon: without activating, the window would open behind the others.
        .onAppear { NSApplication.shared.activate() }
        // Back from System Settings, where a permission may have just been granted.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshPermissions() }
        }
    }

    /// A button for a step whose system prompt brings another app to the front: the window comes
    /// back when it is answered.
    private func button(_ title: LocalizedStringKey, action: @escaping () async -> Void) -> some View {
        HStack {
            Button(title) {
                let window = NSApplication.shared.keyWindow
                Task {
                    await action()
                    await Self.bringBack(window)
                }
            }
            Spacer()
        }
    }

    private func settingsLink(_ message: LocalizedStringKey, open: @escaping () -> Void) -> some View {
        HStack {
            Text(message).foregroundStyle(.secondary)
            Spacer()
            Button("Open System Settings", action: open)
        }
    }

    /// Waits for the system prompt to go, then fronts the window again (from Takku).
    private static func bringBack(_ window: NSWindow?) async {
        for _ in 0..<480 {
            guard let front = NSWorkspace.shared.frontmostApplication,
                  front != .current,
                  front.activationPolicy != .regular
            else { break }
            try? await Task.sleep(for: .milliseconds(250))
        }
        NSApplication.shared.activate()
        window?.orderFrontRegardless()
        window?.makeKey()
    }
}

/// Where the speech model is: downloading, preparing, ready or failed, with a way to retry.
struct SpeechModelStatus: View {
    let model: SpeechModel

    var body: some View {
        switch model.state {
        case .notLoaded:
            HStack {
                Text("Parakeet v3, \(SpeechModel.downloadMB) MB, downloaded once.").foregroundStyle(.secondary)
                Spacer()
                Button("Download") { Task { try? await model.prepare() } }
            }
        case .downloading(let percent):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(percent), total: 100)
                Text("Downloading Parakeet v3… \(percent)%").font(.caption).foregroundStyle(.secondary)
            }
        case .preparing(let firstTime):
            HStack {
                ProgressView().controlSize(.small)
                Text(firstTime
                    ? "Preparing the model for this Mac. It takes a few minutes, only once."
                    : "Loading the model…")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .ready:
            Text("Parakeet v3 is ready.").foregroundStyle(.secondary)
        case .failed(let detail):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("The model could not be loaded.")
                    Spacer()
                    Button("Retry") { Task { try? await model.prepare() } }
                }
                Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}

private struct Step: View {
    let number: Int
    let title: LocalizedStringKey
    let isDone: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "\(number).circle")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
            Text(title)
        }
    }
}
