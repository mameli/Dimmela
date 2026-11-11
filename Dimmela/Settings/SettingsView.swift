import AppKit
import DimmelaCore
import SwiftUI

/// The Settings tabs. Stored, so other windows can open Settings on one of them.
enum SettingsTab: String {
    case general, transcription, postProcessing, modes, about

    static let key = "settingsTab"

    /// The next time Settings opens, or now if it is open.
    @MainActor static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: key)
    }
}

struct SettingsView: View {
    let model: AppModel
    @AppStorage(SettingsTab.key) private var tab = SettingsTab.general

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: .general) { GeneralSettings(model: model, updates: model.updates) }
            Tab("Transcription", systemImage: "waveform", value: .transcription) { TranscriptionSettings(model: model.speechModel) }
            Tab("Post-processing", systemImage: "sparkles", value: .postProcessing) { PostProcessingSettings() }
            Tab("Modes", systemImage: "list.number", value: .modes) { ModeSettings() }
            Tab("About", systemImage: "info.circle", value: .about) { AboutSettings(updates: model.updates) }
        }
        .frame(width: 560, height: 460)
    }
}

private struct TranscriptionSettings: View {
    let model: SpeechModel
    @State private var error: String?
    /// Changes when a model is deleted, so the rows read the disk again.
    @State private var deletions = 0

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: Binding(get: { model.choice }, set: { model.choose($0) })) {
                    ForEach(SpeechModelChoice.allCases) { choice in
                        Text("\(choice.name) (\(choice.downloadMB) MB)").tag(choice)
                    }
                }
                Text(model.choice.note).font(.caption).foregroundStyle(.secondary)
                SpeechModelStatus(model: model)
                if model.state == .ready || model.choice.isDownloaded {
                    HStack {
                        Button("Delete the Model", role: .destructive) {
                            do { try model.delete() } catch { self.error = error.localizedDescription }
                            deletions += 1
                        }
                        Button("Download Again") {
                            do {
                                try model.delete()
                                Task { try? await model.prepare() }
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                        Spacer()
                    }
                }
                ForEach(SpeechModelChoice.allCases.filter { $0 != model.choice && $0.isDownloaded }) { other in
                    HStack {
                        Text("\(other.name) is also on this Mac (\(other.downloadMB) MB).").foregroundStyle(.secondary)
                        Spacer()
                        Button("Delete", role: .destructive) {
                            do { try model.delete(other) } catch { self.error = error.localizedDescription }
                            deletions += 1
                        }
                    }
                }
                .id(deletions)
                if let error {
                    Text(error).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text("Speech model")
            } footer: {
                Text("Parakeet runs on this Mac and recognizes Italian, English and 23 other European languages by itself. Each model is downloaded once from Hugging Face: no audio or text leaves the Mac. Only the chosen model stays in memory.")
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

private struct ModeSettings: View {
    @AppStorage(AppSettings.modeSourcesKey) private var sources = ""
    @AppStorage(AppSettings.enabledModesKey) private var enabled = ""
    @AppStorage(AppSettings.defaultModeKey) private var defaultModeID = ""
    /// Read again when the window appears, so new files in a source show up.
    @State private var available: [Mode] = []
    /// Read when the tab appears: apps come and go.
    @State private var editors = TextEditors.none
    @State private var pendingDeletion: Mode?
    @State private var trashError: String?

    private var sourceList: [String] { AppSettings.lines(of: sources) }
    private var enabledModes: [Mode] { AppSettings.lines(of: enabled).map(Mode.init(id:)) }

    var body: some View {
        Form {
            Section {
                Picker("Default Mode", selection: $defaultModeID) {
                    Text("None").tag("")
                    ForEach(enabledModes) { Text($0.name).tag($0.id) }
                }
            }
            Section {
                List {
                    ForEach(enabledModes) { mode in
                        ModeRow(mode: mode, isEnabled: true, editors: editors, trash: { pendingDeletion = mode }) { toggle(mode) }
                    }
                    .onMove(perform: move)
                }
                .frame(minHeight: 80)
            } header: {
                Text("Enabled Modes")
            } footer: {
                Text("Drag to reorder; ⋯ edits a Mode in your editor.").foregroundStyle(.secondary)
            }
            Section("Available") {
                let others = available.filter { !enabledModes.contains($0) }
                if others.isEmpty {
                    Text(sourceList.isEmpty ? "Add a folder of prompt files or skills." : "Nothing else in the Mode sources.")
                        .foregroundStyle(.secondary)
                }
                ForEach(others) { mode in
                    ModeRow(mode: mode, isEnabled: false, editors: editors, trash: { pendingDeletion = mode }) { toggle(mode) }
                }
            }
            Section {
                ForEach(sourceList, id: \.self) { path in
                    HStack {
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Remove", role: .destructive) { removeSource(path) }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…", action: addSource)
            } header: {
                Text("Mode sources")
            } footer: {
                Text("Folders of prompt files (Markdown) or skills (folders with a SKILL.md). Clean and Markdown are in ~/.dimmela/modes.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            editors = .markdown()
            reload()
        }
        .onChange(of: sources) { reload() }
        // Back from the editor or Finder, where Modes can be added or renamed.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in reload() }
        .confirmationDialog(
            "Move the Mode \"\(pendingDeletion?.name ?? "")\" to the Trash?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
        ) {
            Button("Move to Trash", role: .destructive) {
                if let mode = pendingDeletion { moveToTrash(mode) }
            }
        } message: {
            Text("Its file goes to the Trash, where you can put it back.")
        }
        .alert("The Mode could not be moved to the Trash", isPresented: Binding(get: { trashError != nil }, set: { if !$0 { trashError = nil } })) {
        } message: {
            Text(trashError ?? "")
        }
    }

    /// The file, or the skill's folder, goes to the Trash; the Mode stops being enabled.
    private func moveToTrash(_ mode: Mode) {
        do {
            try FileManager.default.trashItem(at: mode.url, resultingItemURL: nil)
        } catch {
            trashError = error.localizedDescription
            return
        }
        AppSettings.enabledModes = enabledModes.filter { $0 != mode }
        if defaultModeID == mode.id { defaultModeID = "" }
        reload()
    }

    private func reload() {
        available = AppSettings.availableModes
    }

    private func addSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.standardizedFileURL.path(percentEncoded: false)
        guard !sourceList.contains(path) else { return }
        AppSettings.modeSources = sourceList + [path]
    }

    private func removeSource(_ path: String) {
        AppSettings.modeSources = sourceList.filter { $0 != path }
    }

    private func toggle(_ mode: Mode) {
        if enabledModes.contains(mode) {
            AppSettings.enabledModes = enabledModes.filter { $0 != mode }
            if defaultModeID == mode.id { defaultModeID = "" }
        } else {
            AppSettings.enabledModes = enabledModes + [mode]
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var modes = enabledModes
        modes.move(fromOffsets: offsets, toOffset: destination)
        AppSettings.enabledModes = modes
    }
}

private struct ModeRow: View {
    let mode: Mode
    let isEnabled: Bool
    let editors: TextEditors
    let trash: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { isEnabled }, set: { _ in toggle() })) {
                VStack(alignment: .leading) {
                    HStack {
                        Text(mode.name)
                        if mode.isMissing {
                            Text("Missing").font(.caption).foregroundStyle(.red)
                        }
                    }
                    Text(mode.isMissing
                        ? "Not found at \(mode.id): the Transcript is pasted instead."
                        : "\(mode.isSkill ? "Skill" : "Prompt file") in \(mode.url.deletingLastPathComponent().lastPathComponent)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)
            Spacer()
            if !mode.isMissing {
                MoreMenu {
                    EditWithMenu(title: "Edit With", editors: editors) { app in
                        TextEditors.open(mode.editableFile, with: app)
                    }
                    Divider()
                    Button("Move to Trash…", role: .destructive, action: trash)
                }
            }
        }
    }
}
