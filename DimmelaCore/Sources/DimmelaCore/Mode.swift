import Foundation

/// A named set of instructions for Post-processing, read from a prompt file in a Mode source.
/// Identified by the file's path, so the user's choices find it again after a relaunch.
public struct Mode: Identifiable, Hashable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public var url: URL { URL(fileURLWithPath: id) }

    /// The file name made readable: "translate-to-english.md" is "Translate to english".
    public var name: String {
        let words = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// The system message, read from disk now so edits apply to the next Dictation. Handy's
    /// `${output}` placeholder is dropped, as Handy does: the Transcript is the user message.
    public func instructions() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .replacingOccurrences(of: "${output}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Finds the Modes in the Mode sources the user pointed Dimmela at.
public enum ModeCatalog {
    /// Source by source, sorted by name within each. A source that no longer exists has none.
    public static func modes(in sources: [URL]) -> [Mode] {
        sources.flatMap { source -> [Mode] in
            let files = (try? FileManager.default.contentsOfDirectory(
                at: source, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
            )) ?? []
            return files
                .filter(isPromptFile)
                .map { Mode(id: $0.standardizedFileURL.path(percentEncoded: false)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private static func isPromptFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "md"
            && url.deletingPathExtension().lastPathComponent.lowercased() != "readme"
            && (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
