import AppKit
import DimmelaCore
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Post-processing", systemImage: "sparkles") { PostProcessingSettings() }
            Tab("Modes", systemImage: "list.number") { ModeSettings() }
            Tab("Vocabulary", systemImage: "character.book.closed") { VocabularySettings() }
        }
        .frame(width: 560, height: 460)
    }
}

private struct PostProcessingSettings: View {
    @AppStorage(AppSettings.providerBaseURLKey) private var baseURL = Provider.openRouter.baseURL
    @AppStorage(AppSettings.providerModelKey) private var model = Provider.openRouter.model
    @State private var apiKey = ""
    @State private var keyStatus = ""
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        Form {
            Section {
                TextField("Base URL", text: $baseURL, prompt: Text(verbatim: Provider.openRouter.baseURL))
                TextField("Model", text: $model, prompt: Text(verbatim: Provider.openRouter.model))
            } footer: {
                Text("Any OpenAI-compatible server. Plain http:// only for a server on this Mac.")
                    .foregroundStyle(.secondary)
            }
            Section {
                SecureField("API key", text: $apiKey)
                    .onSubmit(saveKey)
                HStack {
                    Button("Save key", action: saveKey)
                    Text(keyStatus).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Stored in the Keychain.").foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Test connection") { Task { await test() } }
                        .disabled(isTesting)
                    if isTesting { ProgressView().controlSize(.small) }
                }
                if let testResult {
                    Text(testResult).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKey = Keychain.apiKey ?? ""
        }
    }

    private func saveKey() {
        do {
            try Keychain.setAPIKey(apiKey)
            keyStatus = apiKey.isEmpty ? "Key removed." : "Key saved."
        } catch {
            keyStatus = error.localizedDescription
        }
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        saveKey()
        do {
            let reply = try await ChatClient.configured().complete([
                ChatMessage(role: .user, content: "Reply with the single word OK."),
            ])
            testResult = "The provider answered: \(reply)"
        } catch {
            testResult = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}

private struct ModeSettings: View {
    @AppStorage(AppSettings.modeSourcesKey) private var sources = ""
    @AppStorage(AppSettings.enabledModesKey) private var enabled = ""
    @AppStorage(AppSettings.defaultModeKey) private var defaultModeID = ""
    /// Read again when the window appears, so new files in a source show up.
    @State private var available: [Mode] = []

    private var sourceList: [String] { AppSettings.lines(of: sources) }
    private var enabledModes: [Mode] { AppSettings.lines(of: enabled).map(Mode.init(id:)) }

    var body: some View {
        Form {
            Section("Mode sources") {
                ForEach(sourceList, id: \.self) { path in
                    HStack {
                        Text(path).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Remove", role: .destructive) { removeSource(path) }
                            .buttonStyle(.borderless)
                    }
                }
                Button("Add Folder…", action: addSource)
            }
            Section {
                List {
                    ForEach(enabledModes) { mode in
                        ModeRow(mode: mode, isEnabled: true) { toggle(mode) }
                    }
                    .onMove(perform: move)
                }
                .frame(minHeight: 80)
            } header: {
                Text("Enabled Modes")
            } footer: {
                Text("Drag to reorder.").foregroundStyle(.secondary)
            }
            Section("Available") {
                let others = available.filter { !enabledModes.contains($0) }
                if others.isEmpty {
                    Text(sourceList.isEmpty ? "Add a folder of prompt files or skills." : "Nothing else in the Mode sources.")
                        .foregroundStyle(.secondary)
                }
                ForEach(others) { mode in
                    ModeRow(mode: mode, isEnabled: false) { toggle(mode) }
                }
            }
            Section {
                Picker("Default Mode", selection: $defaultModeID) {
                    Text("None").tag("")
                    ForEach(enabledModes) { Text($0.name).tag($0.id) }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: reload)
        .onChange(of: sources) { reload() }
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

private struct VocabularySettings: View {
    @AppStorage(AppSettings.vocabularyKey) private var text = ""

    private var count: Int { Vocabulary(text: text).entries.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Vocabulary.example)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(.background))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator))
            Text(count == 1 ? "1 entry" : "\(count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct ModeRow: View {
    let mode: Mode
    let isEnabled: Bool
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
        }
    }
}
