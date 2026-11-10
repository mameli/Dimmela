import CryptoKit
import Foundation

/// One Post-processing as the Post-processing log keeps it, to improve the Modes' prompts
/// later with a model of the user's choice: what went in, what came out, and with what.
public struct PostProcessingRecord: Codable, Equatable, Sendable {
    /// The Dictation's History entry: the same for its Post-processing again.
    public let dictationID: UUID
    public let date: Date
    public let mode: String
    /// The prompt file or skill folder.
    public let modeFile: String
    /// The first 8 hex digits of the SHA-256 of the Mode's instructions, without the
    /// Vocabulary: the same prompt has the same value, an edited one a new value.
    public let promptVersion: String
    public let model: String
    /// A `Provider.ReasoningEffort` raw value; nil for the model's default.
    public let reasoning: String?
    public let hasExtraParameters: Bool
    /// From the History menu, not from a Dictation.
    public let isAgain: Bool
    public let transcript: String
    /// The LLM's answer; nil when it failed.
    public let text: String?
    public let error: String?
    public let seconds: Double
    /// The requests sent: more than 1 when the provider failed for a passing reason and the
    /// request was sent again. `seconds` includes the pauses between them.
    public let attempts: Int
    /// The Provider profile's name: a fallback one when the profile in use failed.
    public let profile: String?

    public init(
        dictationID: UUID, date: Date = .now, mode: Mode, instructions: String, client: ChatClient, isAgain: Bool, transcript: String,
        text: String?, error: String?, seconds: Double, attempts: Int = 1, profile: String? = nil
    ) {
        self.dictationID = dictationID
        self.date = date
        self.mode = mode.name
        modeFile = mode.id
        promptVersion = Self.version(of: instructions)
        model = client.model
        reasoning = client.reasoning?.rawValue
        hasExtraParameters = client.hasExtraParameters
        self.isAgain = isAgain
        self.transcript = transcript
        self.text = text
        self.error = error
        self.seconds = (seconds * 100).rounded() / 100
        self.attempts = attempts
        self.profile = profile
    }

    static func version(of instructions: String) -> String {
        SHA256.hash(data: Data(instructions.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    /// The record as one line of JSON, for a `.jsonl` file.
    public var jsonLine: String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // The same order on every line, transcript and text side by side at the end.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }
}
