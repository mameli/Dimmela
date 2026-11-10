import DimmelaCore
import Foundation

/// Stands in for the microphone, the speech model and the paste: records what the controller
/// asked of them and returns prepared answers.
@MainActor
final class FakeBoundaries {
    var samples: [Float] = [0.1, 0.2, 0.3]
    /// Where the voice activity detector finds speech; all of it by default.
    var findSpeech: ([Float]) throws -> Range<Int>? = { 0..<$0.count }
    var transcript: Result<String, Error> = .success("Ciao, sto provando Dimmela.")
    var startError: Error?
    var pasteError: Error?
    var defaultMode: Mode?
    var enabledModes: [Mode] = []
    var vocabulary = Vocabulary(text: "")
    /// Thrown instead of building the chat client, as when no provider is configured.
    var chatClientError: Error?
    let provider = StubTransport()
    /// The fallback profiles after the one in use, by name, in order.
    var fallbacks: [(name: String, transport: StubTransport)] = []
    /// The profile in use, in place of "OpenRouter" answering through `provider`.
    var inUse: NamedChatClient?
    /// No profile at all, as when the user removed every one.
    var hasNoProfile = false
    var fallbackBudget: Duration = .seconds(20)
    /// The pauses before a request was sent again, recorded instead of waited.
    let pauses = Pauses()
    let historyFolder = TemporaryFolder()
    lazy var history = History(directory: historyFolder.url)

    private(set) var recordingStarted = 0
    private(set) var recordingStopped = 0
    private(set) var transcribed: [[Float]] = []
    private(set) var pasted: [String] = []
    private(set) var problems: [DictationProblem] = []
    private(set) var records: [PostProcessingRecord] = []
    /// The controller's phase while the speech model was working.
    private(set) var phaseDuringTranscription: DictationController.Phase?

    /// While true, the speech model does not answer until `finishTranscription()`.
    var holdsTranscription = false
    private(set) var isTranscribing = false
    private var transcriptionGate: CheckedContinuation<Void, Never>?

    weak var controller: DictationController?

    func controllerWired() -> DictationController {
        let controller = DictationController(boundaries: DictationBoundaries(
            startRecording: { [unowned self] in
                if let startError { throw startError }
                recordingStarted += 1
            },
            stopRecording: { [unowned self] in
                recordingStopped += 1
                return samples
            },
            findSpeech: { [unowned self] samples in try findSpeech(samples) },
            transcribe: { [unowned self] samples in
                transcribed.append(samples)
                phaseDuringTranscription = self.controller?.phase
                if holdsTranscription {
                    isTranscribing = true
                    await withCheckedContinuation { transcriptionGate = $0 }
                    isTranscribing = false
                }
                return try transcript.get()
            },
            paste: { [unowned self] text in
                if let pasteError { throw pasteError }
                pasted.append(text)
            },
            report: { [unowned self] problem in problems.append(problem) },
            defaultMode: { [unowned self] in defaultMode },
            setDefaultMode: { [unowned self] mode in defaultMode = mode },
            enabledModes: { [unowned self] in enabledModes },
            vocabulary: { [unowned self] in vocabulary },
            history: history,
            chatClients: { [unowned self] in
                guard !hasNoProfile else { return [] }
                let first = inUse ?? NamedChatClient(name: "OpenRouter") {
                    if let chatClientError { throw chatClientError }
                    return Self.client(provider)
                }
                return [first] + fallbacks.map { fallback in NamedChatClient(name: fallback.name) { Self.client(fallback.transport) } }
            },
            fallbackBudget: fallbackBudget,
            recordPostProcessing: { [unowned self] record in records.append(record) },
            sleep: { [pauses] wait in try await pauses.sleep(wait) }
        ))
        self.controller = controller
        return controller
    }
}

/// Records the pauses asked for and returns at once; `whileWaiting` runs inside each one.
final class Pauses: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Duration] = []
    var whileWaiting: (@Sendable () async throws -> Void)?

    var all: [Duration] { lock.withLock { recorded } }

    func sleep(_ wait: Duration) async throws {
        lock.withLock { recorded.append(wait) }
        try await whileWaiting?()
        try Task.checkCancellation()
    }
}

extension FakeBoundaries {
    nonisolated static func client(_ transport: StubTransport) -> ChatClient {
        ChatClient(
            baseURL: URL(string: "https://openrouter.ai/api/v1")!, apiKey: "sk-test",
            model: "anthropic/claude-haiku-5.5", reasoning: .low, transport: transport.send
        )
    }
}

struct Failure: Error, CustomStringConvertible {
    var description: String { "boom" }
}

extension FakeBoundaries {
    func finishTranscription() {
        transcriptionGate?.resume()
        transcriptionGate = nil
    }

    /// Waits until the controller is inside the speech model.
    func untilTranscribing() async {
        while !isTranscribing { await Task.yield() }
    }
}
