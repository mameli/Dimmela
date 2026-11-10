import AppKit
import DimmelaCore
import SwiftUI

/// Settings › Post-processing: the Provider profiles, the editor of the one chosen in the list,
/// and the Post-processing log.
struct PostProcessingSettings: View {
    @AppStorage(AppSettings.providerProfilesKey) private var profiles = ProviderProfiles()
    @AppStorage(AppSettings.keepsPostProcessingLogKey) private var keepsPostProcessingLog = false
    /// The profile open in the editor, not necessarily the one in use.
    @State private var editedID: UUID?

    var body: some View {
        Form {
            Section {
                if profiles.all.isEmpty {
                    Text("No Provider profile yet. Add one to use Modes.")
                        .foregroundStyle(.secondary)
                }
                List {
                    ForEach(profiles.all) { profile in
                        ProfileRow(profile: profile, isInUse: profile.id == profiles.selected?.id, isEdited: profile.id == editedID)
                            .contentShape(Rectangle())
                            .onTapGesture { editedID = profile.id }
                    }
                    .onMove { profiles.move(fromOffsets: $0, toOffset: $1) }
                }
                .frame(minHeight: CGFloat(max(profiles.all.count, 1)) * 40)
                addAndRemove
            } header: {
                Text("Provider profiles")
            } footer: {
                Text("Any OpenAI-compatible server, or a coding agent you already pay for. Post-processing uses the profile marked In use; if it still fails after asking again, the profiles marked Fallback are tried in this order, drag to reorder. After 20 seconds no other profile is tried and the Transcript is pasted.")
                    .foregroundStyle(.secondary)
            }

            if let index = profiles.all.firstIndex(where: { $0.id == editedID }) {
                ProfileEditor(
                    profile: $profiles.all[index],
                    isInUse: profiles.all[index].id == profiles.selected?.id,
                    use: { profiles.selectedID = profiles.all[index].id }
                )
                .id(profiles.all[index].id)
            }

            Section {
                Toggle("Keep a Post-processing log", isOn: $keepsPostProcessingLog)
                if keepsPostProcessingLog {
                    Button("Show in Finder") {
                        let log = AppSettings.postProcessingLog.url
                        if FileManager.default.fileExists(atPath: log.path(percentEncoded: false)) {
                            NSWorkspace.shared.activateFileViewerSelecting([log])
                        } else {
                            NSWorkspace.shared.open(log.deletingLastPathComponent())
                        }
                    }
                }
            } footer: {
                Text("Each Transcript with the Mode, the prompt version, the model and the LLM's answer, one JSON line per Post-processing in ~/.dimmela/post-processing.jsonl, about 1 MB at most: to improve your Modes' prompts with a model of your choice, adding your own \"comment\" where the answer was not what you wanted. Dimmela only adds lines at the end. It holds what you dictate, so it is never part of Report a Problem.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { editedID = editedID ?? profiles.selected?.id }
    }

    /// + and − under the list, as in the Mac's own lists. The + offers an empty profile, one
    /// started from a common server, and the coding agents' CLIs not added yet: they are offered
    /// even when not installed, and their editor says what is missing.
    private var addAndRemove: some View {
        HStack(spacing: 12) {
            Menu {
                Button("New Profile") { add(ProviderProfile(name: "", provider: Provider(baseURL: "", model: ""))) }
                Divider()
                ForEach(ProviderProfile.presets) { preset in
                    Button(preset.name) { add(preset.copy()) }
                }
                let offeredCLIs = AgentCLI.allCases.filter { cli in !profiles.all.contains { $0.agentCLI == cli } }
                if !offeredCLIs.isEmpty {
                    Section("With your coding agent's plan") {
                        ForEach(offeredCLIs, id: \.self) { cli in
                            Button(cli.name) { add(cli.profile()) }
                        }
                    }
                }
            } label: {
                Image(systemName: "plus").accessibilityLabel(Text("Add Profile"))
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add Profile")
            Button {
                guard let id = editedID else { return }
                Keychain.deleteAPIKey(for: id)
                profiles.remove(id)
                editedID = profiles.selected?.id
            } label: {
                Image(systemName: "minus").accessibilityLabel(Text("Remove Profile"))
            }
            .buttonStyle(.borderless)
            .disabled(editedID == nil)
            .help("Remove Profile")
            Spacer()
        }
    }

    /// Opened in the editor; in use only if it is the first one, else the user chooses when it works.
    private func add(_ profile: ProviderProfile) {
        profiles.add(profile)
        editedID = profile.id
    }
}

private struct ProfileRow: View {
    let profile: ProviderProfile
    let isInUse: Bool
    let isEdited: Bool

    var body: some View {
        HStack {
            Image(systemName: isEdited ? "pencil.circle.fill" : "circle")
                .foregroundStyle(isEdited ? Color.accentColor : .secondary)
            VStack(alignment: .leading) {
                Text(profile.displayName)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isInUse {
                Text("In use").font(.caption).foregroundStyle(.green)
            } else if profile.isFallback {
                Text("Fallback").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var caption: String {
        let model = profile.provider.model
        switch profile.agentCLI {
        case .codex: return "Your ChatGPT plan, through Codex" + (model.isEmpty ? "" : " · \(model)")
        case .copilot: return "Your GitHub Copilot plan" + (model.isEmpty ? "" : " · \(model)")
        case .claude: return "Your Claude plan, through Claude Code" + (model.isEmpty ? "" : " · \(model)")
        case .opencode: return model.isEmpty ? "To be configured" : "Through OpenCode · \(model)"
        case .pi: return model.isEmpty ? "To be configured" : "Through Pi · \(model)"
        case nil: return model.isEmpty ? "To be configured" : model
        }
    }
}

private struct ProfileEditor: View {
    @Binding var profile: ProviderProfile
    let isInUse: Bool
    let use: () -> Void

    /// The Extra parameters as typed: they reach the profile only when valid.
    @State private var extraParameters = ""
    @State private var extraParametersProblem: String?
    @State private var keySuffix: String?
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
        Section {
            LabeledContent("Name") {
                TextField("Name", text: $profile.name, prompt: Text(verbatim: profile.displayName))
                    .labelsHidden()
            }
            if let cli = profile.agentCLI {
                AgentCLIRows(cli: cli, provider: $profile.provider)
            } else {
                providerRows
            }
        } header: {
            Text("Profile: \(profile.displayName)")
        } footer: {
            if profile.agentCLI == nil {
                HStack(spacing: 4) {
                    Text("Plain http:// only for a server on this Mac. The key is stored in the macOS Keychain, never in a file.")
                    if profile.provider.baseURL.contains("openrouter.ai") {
                        Link("Get an OpenRouter key", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }

        if profile.agentCLI == nil {
            reasoningAndExtraParameters
        }

        Section {
            HStack {
                Button("Test Connection") { Task { await runTest() } }
                    .disabled(isTesting || urlProblem != nil || extraParametersProblem != nil)
                if isTesting { ProgressView().controlSize(.small) }
                Spacer()
                if isInUse {
                    Text("Used for Post-processing").foregroundStyle(.green)
                } else {
                    Button("Use for Post-processing", action: use)
                }
            }
            if !isInUse {
                Toggle("Use as fallback", isOn: $profile.isFallback)
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
            Text("Sends a one-word request to the model, with the same settings as a Dictation. During a Dictation a busy provider is asked again twice, a few seconds apart; if it still fails or does not answer within 30 seconds, the Transcript is pasted instead.")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            extraParameters = profile.provider.extraParameters ?? ""
            keySuffix = storedKeySuffix
        }
        .onChange(of: profile.provider.baseURL) { test = nil }
        .onChange(of: profile.provider.model) { test = nil }
        .onChange(of: profile.provider.reasoning) { test = nil }
        .onChange(of: extraParameters) { saveExtraParameters() }
    }

    /// An OpenAI-compatible server: its address, model and key.
    @ViewBuilder private var providerRows: some View {
        LabeledContent("Base URL") {
            TextField("Base URL", text: $profile.provider.baseURL, prompt: Text(verbatim: Provider.openRouter.baseURL))
                .labelsHidden()
        }
        if let urlProblem {
            Label(urlProblem, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        LabeledContent("Model") {
            TextField("Model", text: $profile.provider.model, prompt: Text(verbatim: Provider.openRouter.model))
                .labelsHidden()
        }
        apiKeyRow
        if let keyError {
            Text(keyError).font(.caption).foregroundStyle(.red)
        }
    }

    private var reasoningAndExtraParameters: some View {
        Section {
            Picker("Reasoning", selection: $profile.provider.reasoning) {
                Text("Model default").tag(Provider.ReasoningEffort?.none)
                ForEach(Provider.ReasoningEffort.allCases, id: \.self) { effort in
                    Text(effort.displayName).tag(Optional(effort))
                }
            }
            LabeledContent("Extra parameters") {
                CodeTextField(placeholder: #"JSON, e.g. {"reasoning_effort": "xhigh"}"#, text: $extraParameters)
            }
            if let extraParametersProblem {
                Text(extraParametersProblem).font(.caption).foregroundStyle(.red)
            }
        } footer: {
            Text("Model default sends nothing. OpenRouter gets the level in its own format, every other provider as reasoning_effort, which not every model accepts. Extra parameters are added to every request as written, each key in place of what Dimmela sends for it: for what a model needs beyond the Reasoning menu, see the provider's documentation.")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var apiKeyRow: some View {
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
    }

    /// Saved only when valid: otherwise the field shows the problem and Post-processing keeps the
    /// last valid parameters.
    private func saveExtraParameters() {
        do {
            profile.provider.extraParameters = try ExtraParameters.parse(extraParameters).isEmpty ? nil : extraParameters
            extraParametersProblem = nil
        } catch {
            extraParametersProblem = error.localizedDescription
        }
        test = nil
    }

    /// The last characters of the saved key, so the user can tell which key it is.
    private var storedKeySuffix: String? {
        guard let key = Keychain.apiKey(for: profile.id), !key.isEmpty else { return nil }
        return String(key.suffix(4))
    }

    private var urlProblem: String? {
        guard profile.agentCLI == nil, !profile.provider.baseURL.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        do {
            _ = try Provider(baseURL: profile.provider.baseURL, model: "x").validatedBaseURL()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    private func saveKey() {
        let key = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try Keychain.setAPIKey(key, for: profile.id)
            keySuffix = storedKeySuffix
            newKey = ""
            isReplacingKey = false
            keyError = nil
            test = nil
        } catch {
            keyError = error.localizedDescription
        }
    }

    private func removeKey() {
        Keychain.deleteAPIKey(for: profile.id)
        keySuffix = nil
        keyError = nil
        test = nil
    }

    private func runTest() async {
        isTesting = true
        defer { isTesting = false }
        let start = ContinuousClock.now
        do {
            _ = try await ChatClient.configured(profile).complete([
                ChatMessage(role: .user, content: "Reply with the single word OK."),
            ])
            let elapsed = (ContinuousClock.now - start).components
            let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
            let model = profile.provider.model.isEmpty ? profile.displayName : profile.provider.model
            test = .success("\(model) answered in \(seconds.formatted(.number.precision(.fractionLength(1)))) s")
        } catch {
            test = .failure((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
    }
}
