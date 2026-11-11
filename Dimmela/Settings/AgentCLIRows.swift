import AppKit
import DimmelaCore
import SwiftUI

/// The editor's rows for a coding agent's CLI (ADR 0005): it needs no key, being the user's own,
/// signed in with their plan. Only the model and how much it reasons can change; an empty model is
/// the agent's own default. From Takku's Profile editor.
struct AgentCLIRows: View {
    let cli: AgentCLI
    @Binding var provider: Provider

    /// Why the CLI cannot be used now (not installed, not signed in), `nil` when it can.
    @State private var problem: String?
    /// The models the agent offers, `nil` when they could not be read.
    @State private var models: [AgentCLI.Model]?
    /// The model is typed (*Other…*) rather than chosen in the menu.
    @State private var typesModel = false
    /// The executable Dimmela runs and its version, to tell two installs apart.
    @State private var install: (path: String, version: String?)?

    var body: some View {
        Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            // On a row always there: the status row below is empty until the first check.
            .task(id: cli) { await check() }
            // Back from Terminal after the CLI's login.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { await check() }
            }
        if let groups = providerGroups {
            groupedModelMenu(groups)
        } else {
            Picker("Model", selection: modelChoice) {
                if cli.hasDefaultModel {
                    Text("\(cli.name)'s default model").tag(ModelChoice.agentDefault)
                } else if provider.model.isEmpty && !typesModel {
                    Text("Choose a model").tag(ModelChoice.unset)
                }
                ForEach(models ?? [], id: \.name) { model in
                    Text(verbatim: model.name).tag(ModelChoice.named(model.name))
                }
                Text("Other…").tag(ModelChoice.other)
            }
        }
        if modelChoice.wrappedValue == .other {
            LabeledContent("Model name") {
                TextField("Model name", text: $provider.model, prompt: Text("As \(cli.name) names it"))
                    .labelsHidden()
            }
        } else if cli.hasDefaultModel && provider.model.isEmpty {
            Text("\(cli.name)'s own default, not the model chosen in your \(cli.name) settings: Dimmela does not read them.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let levels = cli.reasoningLevels(for: provider.model, in: models) {
            Picker("Reasoning", selection: $provider.reasoning) {
                Text("Model default").tag(Provider.ReasoningEffort?.none)
                ForEach(levels, id: \.self) { effort in
                    Text(effort.displayName).tag(Provider.ReasoningEffort?.some(effort))
                }
            }
            .disabled(levels.isEmpty)
            .onChange(of: levels, initial: true) {
                // A level the new model refuses would make every Post-processing fail.
                if let reasoning = provider.reasoning, !levels.contains(reasoning) { provider.reasoning = nil }
            }
        }
        Group {
            if let problem {
                Text(problem).foregroundStyle(.orange)
            } else if let install {
                if let version = install.version {
                    Text("Runs \(install.path), version \(version).")
                } else {
                    Text("Runs \(install.path).")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(problem == nil ? .secondary : .primary)
        .textSelection(.enabled)
    }

    /// What the agent does with the Transcript, and how long a Dictation waits for it: measured
    /// with a short Italian Dictation and a small model (Takku's flags, November 2026).
    private var description: String {
        let wait = "Each Dictation waits for a run of the CLI"
        return switch cli {
        case .codex:
            "Post-processing by the Codex CLI on this Mac, with the ChatGPT plan you signed in to it with: no key here. The Transcript goes to OpenAI under your plan's terms. Each request is a run of codex exec that keeps nothing and uses none of your Codex settings. \(wait): about 6 seconds, the slowest of the agents."
        case .copilot:
            "Post-processing by the GitHub Copilot CLI on this Mac, with the Copilot plan you signed in to it with: no key here. Each Dictation costs premium requests of your plan, and the Transcript goes to GitHub and its model providers under your plan's terms. Each run keeps nothing and uses none of your Copilot settings. \(wait): 3 to 7 seconds."
        case .claude:
            "Post-processing by the Claude Code CLI on this Mac, with the Claude plan you signed in to it with: no key here. The Transcript goes to Anthropic under your plan's terms. Each run keeps nothing and uses none of your Claude Code settings. \(wait): about 3 seconds."
        case .opencode:
            "Post-processing by the OpenCode CLI on this Mac, with a plan you signed in to through it: no key here. The Transcript goes to the model's provider under your plan's terms. Each run uses none of your OpenCode settings, and Dimmela deletes its session afterwards. \(wait): 2 to 3 seconds."
        case .pi:
            "Post-processing by the Pi CLI on this Mac, with a plan you signed in to through it: no key here. The Transcript goes to the model's provider under your plan's terms. Each run keeps nothing and uses none of your extensions, skills or instructions. \(wait): 1 to 2 seconds."
        }
    }

    private enum ModelChoice: Hashable {
        case agentDefault, named(String), other, unset
    }

    /// OpenCode's and Pi's `provider/model` lists run to hundreds: one submenu per provider.
    private var providerGroups: [(provider: String, models: [AgentCLI.Model])]? {
        guard let models, models.count > 20, models.allSatisfy({ $0.name.contains("/") }) else { return nil }
        return Dictionary(grouping: models) { String($0.name.prefix { $0 != "/" }) }
            .sorted { $0.key < $1.key }
            .map { (provider: $0.key, models: $0.value) }
    }

    @ViewBuilder private func groupedModelMenu(_ groups: [(provider: String, models: [AgentCLI.Model])]) -> some View {
        let choice = modelChoice
        LabeledContent("Model") {
            Menu {
                if cli.hasDefaultModel {
                    Button("\(cli.name)'s default model") { choice.wrappedValue = .agentDefault }
                }
                ForEach(groups, id: \.provider) { group in
                    Menu(group.provider) {
                        ForEach(group.models, id: \.name) { model in
                            Button { choice.wrappedValue = .named(model.name) } label: {
                                Text(verbatim: String(model.name.dropFirst(group.provider.count + 1)))
                            }
                        }
                    }
                }
                Divider()
                Button("Other…") { choice.wrappedValue = .other }
            } label: {
                switch choice.wrappedValue {
                case .agentDefault: Text("\(cli.name)'s default model")
                case .unset: Text("Choose a model")
                case .named(let model): Text(verbatim: model)
                case .other: Text("Other…")
                }
            }
            .fixedSize()
        }
    }

    /// The model menu's choice: the agent's default for no model, *Other…* for a model the menu
    /// does not list, which is then typed.
    private var modelChoice: Binding<ModelChoice> {
        Binding {
            let model = provider.model.trimmingCharacters(in: .whitespaces)
            if typesModel { return .other }
            if model.isEmpty { return cli.hasDefaultModel ? .agentDefault : .unset }
            return models?.contains { $0.name == model } == true ? .named(model) : .other
        } set: { choice in
            typesModel = choice == .other
            switch choice {
            case .agentDefault, .unset: provider.model = ""
            case .named(let model): provider.model = model
            case .other: break
            }
        }
    }

    /// The agent's problem, read again when the user comes back from Terminal, and its models when
    /// none are read yet or the problem changed (a list is a run of the CLI: Copilot's takes seconds).
    private func check() async {
        // Looked up again: the user may have installed it elsewhere meanwhile.
        let executable = await cli.executable(refresh: true)
        let runner = AgentCLI.Runner(cli)
        let unavailability = await runner.unavailability()
        let changed = unavailability?.localizedDescription != problem
        problem = unavailability?.localizedDescription
        let version = executable == nil ? nil : await runner.version()
        install = executable.map { (path: ($0.path as NSString).abbreviatingWithTildeInPath, version: version) }
        if unavailability != .notInstalled(cli) && (models == nil || changed) { models = await runner.models() }
    }
}
