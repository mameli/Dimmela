import AppKit
import SwiftUI

/// Settings › About: who Dimmela is, updates, and where to report a problem.
struct AboutSettings: View {
    let updates: UpdateChecker

    var body: some View {
        Form {
            Section {
                AppIdentity().padding(.vertical, 8)
            }

            Section {
                UpdatesToggle()
                HStack {
                    Button("Check Now") { Task { await updates.check() } }
                        .disabled(updates.isChecking)
                    if updates.isChecking { ProgressView().controlSize(.small) }
                    Spacer()
                    if let release = updates.available {
                        Button("Download Dimmela \(release.version)…") { updates.openReleasePage() }
                    }
                }
                if let status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Updates")
            }

            Section {
                HStack {
                    Button("Report a Problem…") { ProblemReporter.report() }
                    Spacer()
                }
            } header: {
                Text("Problems")
            } footer: {
                Text("Writes a report with the version, macOS, the model in use and Dimmela's recent log, shows it in Finder and opens the GitHub bug form with the same fields filled in. Nothing is sent: check the file and attach it. It holds no Transcripts and no text you dictated.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("dimmela.app", destination: URL(string: "https://dimmela.app")!)
                Link("Source code and documentation", destination: URL(string: "https://github.com/mameli/Dimmela")!)
                Link("Prompts to use as Modes", destination: URL(string: "https://github.com/mameli/dimmela-config")!)
            } header: {
                Text("Links")
            }

            // At the bottom, in grey: seen by those who scroll this far, not first thing (from Takku).
            Section {
            } footer: {
                Text(Self.supportNote)
                    .foregroundStyle(.secondary)
                    .tint(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
    }

    private var status: String? {
        if let problem = updates.lastProblem { return "The last check failed: \(problem)" }
        guard let checked = updates.lastChecked else { return nil }
        let when = checked.formatted(date: .abbreviated, time: .shortened)
        return updates.available == nil ? "Up to date, checked \(when)." : "A new version is available, checked \(when)."
    }

    /// The link is grey like the text around it, so it is underlined to show it is one.
    private static var supportNote: AttributedString {
        var note = AttributedString(localized: "Dimmela is free. If it is useful to you, [buy me a coffee](https://buymeacoffee.com/mameli.dev).")
        for run in note.runs where run.link != nil {
            note[run.range].underlineStyle = .single
        }
        return note
    }
}
