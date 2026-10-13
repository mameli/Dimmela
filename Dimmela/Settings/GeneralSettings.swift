import AppKit
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

/// Where the Vocabulary file is, how many entries it has, and a menu of the apps that can edit
/// it, the system's default for Markdown first.
struct VocabularyFileRow: View {
    @State private var count = AppSettings.vocabulary.entries.count
    @State private var error: String?
    /// The apps that can open the file, read when the row appears.
    @State private var editors: [URL] = []
    @State private var defaultEditor: URL?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "~/.dimmela/vocabulary.md")
                Text(count == 1 ? "1 entry" : "\(count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu("Edit Vocabulary With") {
                ForEach(editors, id: \.self) { app in
                    Button {
                        edit(with: app)
                    } label: {
                        Label {
                            Text(verbatim: app == defaultEditor ? "\(Self.name(of: app)) (default)" : Self.name(of: app))
                        } icon: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path(percentEncoded: false)))
                        }
                    }
                }
            }
            .fixedSize()
        }
        .onAppear(perform: findEditors)
        // Back from the editor: the entries may have changed.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            count = AppSettings.vocabulary.entries.count
        }
        if let error {
            Text(error).foregroundStyle(.secondary)
        }
    }

    private func findEditors() {
        try? AppSettings.createVocabularyFileIfNeeded()
        let file = AppSettings.vocabularyFile
        defaultEditor = NSWorkspace.shared.urlForApplication(toOpen: file)
        var seen = Set<String>()
        let others = NSWorkspace.shared.urlsForApplications(toOpen: file)
            .filter { $0 != defaultEditor && seen.insert(Self.name(of: $0)).inserted }
            .sorted { Self.name(of: $0).localizedStandardCompare(Self.name(of: $1)) == .orderedAscending }
        editors = (defaultEditor.map { [$0] } ?? []) + others
    }

    private func edit(with app: URL) {
        do {
            try AppSettings.createVocabularyFileIfNeeded()
            NSWorkspace.shared.open([AppSettings.vocabularyFile], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private static func name(of app: URL) -> String {
        FileManager.default.displayName(atPath: app.path(percentEncoded: false))
            .replacingOccurrences(of: ".app", with: "")
    }
}

struct GeneralSettings: View {
    var body: some View {
        Form {
            Section {
                AppIdentity().padding(.vertical, 8)
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
                Text("Names and terms speech recognition gets wrong, one per line: `- Jira = gira, ira | the issue tracker at work`. Dimmela reads the file at every Dictation.")
                    .foregroundStyle(.secondary)
            }
            Section {
                UpdatesToggle()
            }
        }
        .formStyle(.grouped)
    }
}
