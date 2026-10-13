import Foundation

/// The user's terms that speech recognition gets wrong: each entry is the correct term,
/// optionally with the variants usually heard instead and a short description. Written as a
/// list in a Markdown file, one entry per line (ported from Takku).
public struct Vocabulary: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let term: String
        public let variants: [String]
        public let description: String?

        public init(term: String, variants: [String] = [], description: String? = nil) {
            self.term = term
            self.variants = variants
            self.description = description
        }
    }

    /// How to write entries. The examples sit inside lines of text, so nothing in it counts until
    /// the user adds list items.
    public static let example = """
        Names, acronyms and technical words that speech recognition gets wrong. One entry per line, \
        starting with `- `: the correct term, then after `=` the variants usually heard instead \
        (optional, comma-separated), then after `|` a short description (optional). \
        Example: `- Jira = gira, ira | the issue tracker at work`
        """

    /// What a new Vocabulary file starts with.
    public static let fileTemplate = "# Vocabulary\n\n\(example)\n\n"

    public let entries: [Entry]

    public init(text: String) {
        var seenTerms = Set<String>()
        var seenVariants = Set<String>()
        var entries: [Entry] = []
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("- ") {
            let (rest, description) = Self.split(line.dropFirst(2), on: "|")
            let (term, variants) = Self.split(rest, on: "=")
            // The first entry counts, for a term and for a variant.
            guard !term.isEmpty, seenTerms.insert(term.lowercased()).inserted else { continue }
            let kept = (variants?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? [])
                .filter { !$0.isEmpty && $0 != term && seenVariants.insert($0.lowercased()).inserted }
            entries.append(Entry(term: term, variants: kept, description: description?.isEmpty == true ? nil : description))
        }
        self.entries = entries
    }

    /// What Post-processing adds after the Mode's instructions: the terms with their
    /// description and variants, and the rule for using them. `nil` if there are no entries.
    var promptBlock: String? {
        guard !entries.isEmpty else { return nil }
        let lines = entries.map { entry in
            var line = "- \(entry.term)"
            if let description = entry.description { line += ": \(description)" }
            if !entry.variants.isEmpty {
                line += " (may be written as \(entry.variants.map { "\"\($0)\"" }.joined(separator: ", ")))"
            }
            return line
        }
        return """
            Vocabulary, names and technical terms the speaker uses:
            \(lines.joined(separator: "\n"))
            The Transcript comes from automatic speech recognition and may spell them wrong. \
            Use the Vocabulary and the context to write them right, but correct a word only when you are sure; \
            otherwise leave it as it is.
            """
    }

    /// Replaces every known variant with its term, whatever its case, whole words only. One pass
    /// with all the variants, longest first, so the longest one wins and a replacement is never
    /// replaced again (ADR 0003).
    func correct(_ text: String) -> String {
        var termFor: [String: String] = [:]
        for entry in entries {
            for variant in entry.variants { termFor[variant.lowercased()] = entry.term }
        }
        let alternatives = termFor.keys.sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
        // Letters and digits next to a variant stop the match: whole words only.
        guard !alternatives.isEmpty,
              let regex = try? NSRegularExpression(
                  pattern: "(?<![\\p{L}\\p{N}])(?:\(alternatives))(?![\\p{L}\\p{N}])", options: .caseInsensitive
              )
        else { return text }

        var output = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            output += text[cursor..<range.lowerBound]
            output += termFor[text[range].lowercased()] ?? String(text[range])
            cursor = range.upperBound
        }
        return output + text[cursor...]
    }

    /// The text before the first `separator`, trimmed, and the trimmed text after it, if any.
    private static func split(_ text: some StringProtocol, on separator: Character) -> (String, String?) {
        guard let index = text.firstIndex(of: separator) else {
            return (text.trimmingCharacters(in: .whitespaces), nil)
        }
        return (
            text[..<index].trimmingCharacters(in: .whitespaces),
            text[text.index(after: index)...].trimmingCharacters(in: .whitespaces)
        )
    }
}
