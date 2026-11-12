import AppKit
import SwiftUI

/// Settings › About: who Dimmela is, updates, the welcome tour, and where to report a problem.
struct AboutSettings: View {
    let updates: UpdateChecker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    /// The page where a payment supports Dimmela: optional, the app is the same without it.
    static let support = URL(string: "https://buy.stripe.com/aFabJ09aafkNbcw3vy6wE06")!

    var body: some View {
        Form {
            Section {
                AppIdentity().padding(.vertical, 8)
            }

            Section {
                HStack {
                    if let release = updates.available {
                        Text("Dimmela \(release.version) is available.")
                        Spacer()
                        Button("Install…") { updates.check() }
                    } else {
                        Text("Check for a new version now, also with the daily check off.")
                            .foregroundStyle(.secondary)
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
            } header: {
                Text("Links")
            }

            Section {
                LabeledContent {
                    Button("Support Dimmela…") { openURL(Self.support) }
                } label: {
                    Text("Dimmela is free and open source. If it is useful to you, you can support its development. It works the same either way.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Support")
            }
        }
        .formStyle(.grouped)
    }
}
