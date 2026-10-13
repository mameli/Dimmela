import AppKit
import DimmelaCore
import SwiftUI

struct SettingsView: View {
    let speechModel: SpeechModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Transcription", systemImage: "waveform") { TranscriptionSettings(model: speechModel) }
            Tab("Post-processing", systemImage: "sparkles") { PostProcessingSettings() }
            Tab("Modes", systemImage: "list.number") { ModeSettings() }
        }
        .frame(width: 560, height: 460)
    }
}

private struct TranscriptionSettings: View {
    let model: SpeechModel
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                SpeechModelStatus(model: model)
                if model.state == .ready || SpeechModel.isDownloaded {
                    HStack {
                        Button("Delete the Model", role: .destructive) {
                            do { try model.delete() } catch { self.error = error.localizedDescription }
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
                if let error {
                    Text(error).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text("Speech model")
            } footer: {
                Text("Parakeet v3 runs on this Mac and recognizes Italian, English and 23 other European languages by itself. It is downloaded once from Hugging Face: no audio or text leaves the Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PostProcessingSettings: View {
    /// Servers people commonly use, to fill the address in one click.
    private static let presets: [(name: String, provider: Provider)] = [
        ("OpenRouter", .openRouter),
        ("LM Studio", Provider(baseURL: "http://localhost:1234/v1", model: "")),
        ("Ollama", Provider(baseURL: "http://localhost:11434/v1", model: "")),
    ]

    @AppStorage(AppSettings.providerBaseURLKey) private var baseURL = Provider.openRouter.baseURL
    @AppStorage(AppSettings.providerModelKey) private var model = Provider.openRouter.model
    @State private var keySuffix = Self.storedKeySuffix
    @State private var isReplacingKey = false
    @State private var newKey = ""
    @State private var keyError: String?
    @State private var test: TestResult?
    @State private var isTesting = false

    private enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Base URL") {
                    HStack {
                        TextField("Base URL", text: $baseURL, prompt: Text(verbatim: Provider.openRouter.baseURL))
                            .labelsHidden()
                        Menu("Presets") {
                            ForEach(Self.presets, id: \.name) { preset in
                                Button(preset.name) {
                                    baseURL = preset.provider.baseURL
                                    if !preset.provider.model.isEmpty { model = preset.provider.model }
                                    test = nil
                                }
                            }
                        }
                        .fixedSize()
                    }
                }
                if let urlProblem {
                    Label(urlProblem, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                LabeledContent("Model") {
                    TextField("Model", text: $model, prompt: Text(verbatim: Provider.openRouter.model))
                        .labelsHidden()
                }
            } header: {
                Text("Provider")
            } footer: {
                Text("Any OpenAI-compatible server. Plain http:// only for a server on this Mac.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("API key") {
                    if let keySuffix, !isReplacingKey {
                        HStack {
                            Text("Saved in the Keychain (…\(keySuffix))")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Button("Replace") { isReplacingKey = true }
                            Button("Remove", role: .destructive, action: removeKey)
                        }
                    } else {
                        HStack {
                            SecureField("API key", text: $newKey, prompt: Text("Paste the key here"))
                                .labelsHidden()
                                .onSubmit(saveKey)
                            Button("Save", action: saveKey)
                                .disabled(newKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if isReplacingKey {
                                Button("Cancel") {
                                    isReplacingKey = false
                                    newKey = ""
                                }
                            }
                        }
                    }
                }
                if let keyError {
                    Text(keyError).font(.caption).foregroundStyle(.red)
                }
            } footer: {
                HStack(spacing: 4) {
                    Text("Stored in the macOS Keychain, never in a file.")
                    if baseURL.contains("openrouter.ai") {
                        Link("Get an OpenRouter key", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Test Connection") { Task { await runTest() } }
                        .disabled(isTesting || urlProblem != nil)
                    if isTesting { ProgressView().controlSize(.small) }
                    Spacer()
                }
                switch test {
                case .success(let message):
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure(let message):
                    Label {
                        Text(message).textSelection(.enabled)
                    } icon: {
                        Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
                    }
                case nil:
                    EmptyView()
                }
            } footer: {
                Text("Sends a one-word request to the model. If the provider does not answer within 30 seconds during a Dictation, the Transcript is pasted instead.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: baseURL) { test = nil }
        .onChange(of: model) { test = nil }
    }

    /// The last characters of the saved key, so the user can tell which key it is.
    private static var storedKeySuffix: String? {
        guard let key = Keychain.apiKey, !key.isEmpty else { return nil }
        return String(key.suffix(4))
    }

    private var urlProblem: String? {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            _ = try Provider(baseURL: baseURL, model: "x").validatedBaseURL()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func saveKey() {
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try Keychain.setAPIKey(key)
            keySuffix = Self.storedKeySuffix
            newKey = ""
            isReplacingKey = false
            keyError = nil
            test = nil
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try Keychain.setAPIKey("")
            keySuffix = nil
            keyError = nil
            test = nil
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func runTest() async {
        isTesting = true
        defer { isTesting = false }
        let start = ContinuousClock.now
        do {
            _ = try await ChatClient.configured().complete([
                ChatMessage(role: .user, content: "Reply with the single word OK."),
            ])
            let elapsed = (ContinuousClock.now - start).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            test = .success("\(model) answered in \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
        } catch {
            test = .failure((error as? LocalizedError)?.errorDescription ?? String(describing: error))
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
