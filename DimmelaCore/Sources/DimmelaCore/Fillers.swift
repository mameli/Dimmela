import Foundation

/// Removes purely vocal Fillers ("ehm", "uhm", "mmh", a lone "eh") from a Transcript, with the
/// punctuation that only served them. Words with meaning ("cioè", "tipo") are never Fillers.
enum Fillers {
    /// The sound, stretched or not ("eh", "eeh", "ehm", "ehmm", "uh", "uhm", "um", "mmh", "hmm"),
    /// as a word of its own: letters, digits, hyphens or apostrophes next to it make it part of
    /// another word ("Bach", "uh-oh"). Then the comma, colon or ellipsis that followed it.
    private static let filler = try! NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}'’\\-])(?:e+h+m*|u+h+m*|u+m+|m+h+|h+m+)(?![\\p{L}\\p{N}'’\\-])(?:\\s*(?:\\.\\.\\.|…|[,;:]))?",
        options: .caseInsensitive
    )

    static func remove(from text: String) -> String {
        let matches = filler.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return text }

        var output = ""
        var cursor = text.startIndex
        var capitalizeNext = false
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            output += piece(text[cursor..<range.lowerBound], capitalize: &capitalizeNext)
            // At the start of a sentence the next word takes the capital the Filler had.
            if isSentenceStart(output) {
                capitalizeNext = true
                output = output.trimmingCharacters(in: .whitespaces)
                if !output.isEmpty { output += " " }
            }
            cursor = range.upperBound
        }
        output += piece(text[cursor...], capitalize: &capitalizeNext)
        return tidy(output)
    }

    /// The text between two Fillers, with its first letter capitalized if needed.
    private static func piece(_ text: Substring, capitalize: inout Bool) -> String {
        guard capitalize else { return String(text) }
        let trimmed = text.drop { $0.isWhitespace || $0 == "." || $0 == "…" }
        guard let first = trimmed.first(where: \.isLetter) else { return String(trimmed) }
        capitalize = false
        let index = trimmed.firstIndex(of: first)!
        return trimmed[..<index] + first.uppercased() + trimmed[trimmed.index(after: index)...]
    }

    private static func isSentenceStart(_ output: String) -> Bool {
        guard let last = output.last(where: { !$0.isWhitespace }) else { return true }
        return ".!?".contains(last)
    }

    /// Spaces and punctuation left behind: double spaces, a space before punctuation, a comma
    /// right before the end of the sentence.
    private static func tidy(_ text: String) -> String {
        var text = text
        for (pattern, template) in [
            ("[ \\t]{2,}", " "),
            ("\\s+([,.;:!?])", "$1"),
            ("[,;:]+([.!?])", "$1"),
            ("^[\\s,;:.…]+", ""),
        ] {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
