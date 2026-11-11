import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The apps that can edit a Markdown file, the system's default for Markdown first. Apps that
/// only show text (browsers, Instruments, Pages…) are left out.
struct TextEditors {
    let apps: [URL]
    let defaultApp: URL?

    static let none = TextEditors(apps: [], defaultApp: nil)

    private init(apps: [URL], defaultApp: URL?) {
        self.apps = apps
        self.defaultApp = defaultApp
    }

    /// Read from Launch Services: call it when the list is shown, apps come and go.
    static func markdown() -> TextEditors {
        let markdown = UTType(filenameExtension: "md") ?? .plainText
        let defaultApp = NSWorkspace.shared.urlForApplication(toOpen: markdown)
        var seen = Set<String>()
        let others = NSWorkspace.shared.urlsForApplications(toOpen: markdown)
            .filter { $0 != defaultApp && editsText($0) && seen.insert(name(of: $0)).inserted }
            .sorted { name(of: $0).localizedStandardCompare(name(of: $1)) == .orderedAscending }
        return TextEditors(apps: (defaultApp.map { [$0] } ?? []) + others, defaultApp: defaultApp)
    }

    static func open(_ file: URL, with app: URL) {
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    static func name(of app: URL) -> String {
        FileManager.default.displayName(atPath: app.path(percentEncoded: false))
            .replacingOccurrences(of: ".app", with: "")
    }


    private static let textTypes: Set<String> = [
        "net.daringfireball.markdown", "public.markdown", "public.plain-text", "public.text", "public.utf8-plain-text",
    ]
    private static let textExtensions: Set<String> = ["md", "markdown", "txt", "text"]
    /// Declare text editing but open it as a table.
    private static let notTextEditors: Set<String> = ["com.apple.iWork.Numbers"]

    /// Whether the app declares the Editor role for Markdown or plain text, not only Viewer, and
    /// not merely for any file at all.
    private static func editsText(_ app: URL) -> Bool {
        guard let bundle = Bundle(url: app),
              !notTextEditors.contains(bundle.bundleIdentifier ?? ""),
              let types = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]]
        else { return false }
        return types.contains { type in
            guard type["CFBundleTypeRole"] as? String == "Editor" else { return false }
            let contentTypes = Set(type["LSItemContentTypes"] as? [String] ?? [])
            let extensions = Set((type["CFBundleTypeExtensions"] as? [String] ?? []).map { $0.lowercased() })
            return !contentTypes.isDisjoint(with: textTypes) || !extensions.isDisjoint(with: textExtensions)
        }
    }
}

/// A menu of the editors, each with its icon, the default one marked: `edit` gets the chosen app.
struct EditWithMenu: View {
    let title: LocalizedStringKey
    let editors: TextEditors
    let edit: (URL) -> Void

    var body: some View {
        Menu(title) {
            ForEach(editors.apps, id: \.self) { app in
                Button {
                    edit(app)
                } label: {
                    AppLabel(app: app, isDefault: app == editors.defaultApp)
                }
            }
        }
        .fixedSize()
    }
}

/// An app's name with its icon, "(default)" after the system's default for Markdown.
struct AppLabel: View {
    let app: URL
    var isDefault = false

    var body: some View {
        Label {
            if isDefault {
                Text("\(TextEditors.name(of: app)) (default)")
            } else {
                Text(verbatim: TextEditors.name(of: app))
            }
        } icon: {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path(percentEncoded: false)))
        }
    }
}

/// ⋯ at the end of a row, for what is done to it less often (from Takku).
struct MoreMenu<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        // A borderless button, not a borderless menu: the same size, colour and place as the
        // IconButtons in the rows next to it.
        Menu(content: content) {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                // Primary, as a menu draws its label whatever colour it is given.
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .accessibilityLabel(Text("More"))
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(Text("More"))
    }
}
