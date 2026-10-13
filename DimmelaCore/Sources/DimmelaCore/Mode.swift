import Foundation

/// A named set of instructions for Post-processing, from a Mode source: a prompt file (a
/// Markdown file) or a skill (a folder with a `SKILL.md`). Identified by the file's or folder's
/// path, so the user's choices find it again after a relaunch.
public struct Mode: Identifiable, Hashable, Sendable {
    public let id: String

    public init(id: String) {
        self.id = id
    }

    public var url: URL { URL(fileURLWithPath: id) }

    public var isSkill: Bool { url.pathExtension.lowercased() != "md" }

    /// Whether its files are gone: Post-processing with it falls back to the Transcript.
    public var isMissing: Bool {
        !FileManager.default.fileExists(atPath: (isSkill ? skillFile : url).path(percentEncoded: false))
    }

    /// The skill's frontmatter `name` or the file name, made readable: "translate-to-english.md"
    /// is "Translate to english".
    public var name: String {
        let raw = (isSkill ? Self.frontmatterName(of: skillFile) : nil)
            ?? url.deletingPathExtension().lastPathComponent
        let words = raw.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    /// Tells the model what a skill, written for an agent, is for here (ADR 0002).
    public static let skillPreamble = """
        You are the final stage of a dictation pipeline. The user message is a raw speech-to-text \
        Transcript dictated by the user. Apply the skill below to it and reply with only the \
        resulting text: no preamble, no explanations, no quotes or code fences around it.
        """

    /// The system message, read from disk now so edits apply to the next Dictation.
    ///
    /// A prompt file is sent as it is, without Handy's `${output}` placeholder (the Transcript is
    /// the user message, as Handy does). A skill is the preamble, its `SKILL.md` without
    /// frontmatter and every Markdown file in its `references/` folder, by name; scripts and other
    /// files are left out.
    public func instructions() throws -> String {
        guard isSkill else {
            return try String(contentsOf: url, encoding: .utf8)
                .replacingOccurrences(of: "${output}", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var parts = [Self.skillPreamble, Self.body(of: try String(contentsOf: skillFile, encoding: .utf8))]
        for reference in references {
            let text = try String(contentsOf: reference, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            parts.append("# File: references/\(reference.lastPathComponent)\n\n\(text)")
        }
        return parts.joined(separator: "\n\n")
    }

    private var skillFile: URL { url.appending(path: "SKILL.md") }

    private var references: [URL] {
        let folder = url.appending(path: "references", directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// The lines between a leading `---` and the next one, if the file starts with them.
    private static func frontmatter(_ text: String) -> (fields: [Substring], body: Substring)? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" })
        else { return nil }
        let body = lines[(end + 1)...].joined(separator: "\n")
        return (Array(lines[1..<end]), Substring(body))
    }

    private static func body(of skill: String) -> String {
        String(frontmatter(skill)?.body ?? Substring(skill)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func frontmatterName(of file: URL) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              let line = frontmatter(text)?.fields.first(where: { $0.hasPrefix("name:") })
        else { return nil }
        let name = line.dropFirst("name:".count).trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return name.isEmpty ? nil : name
    }
}

/// Finds the Modes in the Mode sources the user pointed Dimmela at.
public enum ModeCatalog {
    /// Source by source, sorted by name within each. A source that no longer exists has none.
    /// Symbolic links are followed: skills are often linked from a shared folder.
    public static func modes(in sources: [URL]) -> [Mode] {
        sources.flatMap { source -> [Mode] in
            let entries = (try? FileManager.default.contentsOfDirectory(
                at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []
            return entries
                .filter { isPromptFile($0) || isSkill($0) }
                .map { Mode(id: identifier(of: $0)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    /// The path without the trailing slash folders get, so it reads the same from anywhere.
    private static func identifier(of url: URL) -> String {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    private static func isPromptFile(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return url.pathExtension.lowercased() == "md"
            && url.deletingPathExtension().lastPathComponent.lowercased() != "readme"
            && FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
            && !isDirectory.boolValue
    }

    private static func isSkill(_ url: URL) -> Bool {
        url.pathExtension.lowercased() != "md"
            && FileManager.default.fileExists(atPath: url.appending(path: "SKILL.md").path(percentEncoded: false))
    }
}
