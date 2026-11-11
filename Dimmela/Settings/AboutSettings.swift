import AppKit
import SwiftUI

/// Settings › About: who Dimmela is, updates, the welcome tour, and where to report a problem.
struct AboutSettings: View {
    let updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                AppIdentity().padding(.vertical, 8)
            }

            Section {
                UpdatesToggle(updates: updates)
                HStack {
                    if let release = updates.available {
                        Text("Dimmela \(release.version) is available.")
                        Spacer()
                        Button("Install…") { updates.check() }
                    } else {
                        Spacer()
                        Button("Check Now") { updates.check() }
                    }
                }
            } header: {
                Text("Updates")
            }

            Section {
                HStack {
                    Button("Welcome Tour…") { openWindow(id: WelcomeView.windowID) }
                    Button("Report a Problem…") { ProblemReporter.report() }
                    Spacer()
                }
            } header: {
                Text("Help")
            } footer: {
                Text("The tour shows the shortcut, the permissions and the Modes again. Report a Problem writes a report with the version, macOS, the model in use and Dimmela's recent log, shows it in Finder and opens the GitHub bug form with the same fields filled in. Nothing is sent: check the file and attach it. It holds no Transcripts and no text you dictated.")
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

    /// The link is grey like the text around it, so it is underlined to show it is one.
    private static var supportNote: AttributedString {
        var note = AttributedString(localized: "Dimmela is free. If it is useful to you, [buy me a coffee](https://buymeacoffee.com/mameli.dev).")
        for run in note.runs where run.link != nil {
            note[run.range].underlineStyle = .single
        }
        return note
    }
}
