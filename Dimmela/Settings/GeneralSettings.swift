import AppKit
import DimmelaCore
import ServiceManagement
import SwiftUI

/// Icon, name and version, at the top of the welcome window and of Settings › General.
struct AppIdentity: View {
    var showsVersion = true

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 6) {
            // From the asset catalog: the icon macOS caches for the app can be an old one (from Takku).
            Image(nsImage: NSImage(named: "AppIcon") ?? NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text(verbatim: "Dimmela").font(.title2.weight(.semibold)).foregroundStyle(.primary)
            if showsVersion {
                Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Starts Dimmela when the user logs in, as a login item registered with macOS: it also appears,
/// and can be turned off, in System Settings › General › Login Items (from Takku).
struct LaunchAtLoginToggle: View {
    @State private var status = SMAppService.mainApp.status
    @State private var error: String?

    var body: some View {
        Toggle("Open at login", isOn: Binding(
            get: { status == .enabled || status == .requiresApproval },
            // A closure, not `setEnabled` itself: Swift 6.3 crashes converting the method.
            set: { setEnabled($0) }
        ))
        // The status can change in System Settings while this window is closed.
        .onAppear { status = SMAppService.mainApp.status }
        if status == .requiresApproval {
            HStack {
                Text("Allow Dimmela in System Settings › Login Items.").foregroundStyle(.secondary)
                Spacer()
                Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
            }
        }
        if let error {
            Text(error).foregroundStyle(.secondary)
        }
    }

    private func setEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        status = SMAppService.mainApp.status
    }
}

/// The daily question to GitHub about a newer release (from Takku).
struct UpdatesToggle: View {
    @AppStorage(AppSettings.checkForUpdatesKey) private var checkForUpdates = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Check for updates", isOn: $checkForUpdates)
            Text("Once a day Dimmela asks GitHub for the latest version; nothing about you or your Dictations is sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// What Dimmela read from the Vocabulary file (how many terms, the first ones) and a menu of the
/// apps that can edit it, the system's default for Markdown first. Apps that only show text (browsers, Instruments,
/// Pages…) are left out.
struct VocabularyFileRow: View {
    @State private var vocabulary = AppSettings.vocabulary
    @State private var error: String?
    /// The apps that can edit the file, read when the row appears.
    @State private var editors = TextEditors.none

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                switch vocabulary.entries.count {
                case 0: Text("No terms yet")
                case 1: Text("1 term")
                case let count: Text("\(count) terms")
                }
                if let preview = vocabulary.preview {
                    Text(verbatim: preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer()
            EditWithMenu(title: "Edit Vocabulary With", editors: editors, edit: edit(with:))
        }
        .onAppear {
            try? AppSettings.createVocabularyFileIfNeeded()
            editors = .markdown()
        }
        // Back from the editor: the entries may have changed.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vocabulary = AppSettings.vocabulary
        }
        if let error {
            Text(error).foregroundStyle(.secondary)
        }
    }

    private func edit(with app: URL) {
        do {
            try AppSettings.createVocabularyFileIfNeeded()
            TextEditors.open(AppSettings.vocabularyFile, with: app)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GeneralSettings: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                HStack {
                    Button("Set Up Dimmela…") { openWindow(id: WelcomeView.windowID) }
                    Spacer()
                }
            } footer: {
                Text("The permissions, the speech model, a test Dictation and the Modes, as at the first launch.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LaunchAtLoginToggle()
            } footer: {
                Text("Dimmela loads the speech model when it starts, so it is ready for the first Dictation after login.")
                    .foregroundStyle(.secondary)
            }
            Section {
                VocabularyFileRow()
            } header: {
                Text("Vocabulary")
            } footer: {
                Text("In ~/.dimmela/vocabulary.md, one per line: `- Jira = gira, ira | the issue tracker at work`. The variants are fixed in the Transcript; Post-processing gets the terms too. Dimmela reads the file at every Dictation.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
