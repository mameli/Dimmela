import Foundation
import Observation

/// What went wrong in a Dictation, for the user to see. The detail is the underlying error.
public enum DictationProblem: Equatable, Sendable {
    case microphoneUnavailable(String)
    case transcriptionFailed(String)
    case pasteFailed(String)
    /// The Transcript was pasted instead of the LLM's answer.
    case postProcessingFailed(String)
    /// Post-processing a History entry again gave no text.
    case postProcessingAgainFailed(String)
}

/// The platform pieces a Dictation needs, injected so the controller can be driven in tests.
public struct DictationBoundaries {
    public var startRecording: @MainActor () throws -> Void
    /// Stops the microphone and returns what it heard: 16 kHz mono samples.
    public var stopRecording: @MainActor () async -> [Float]
    /// Where the voice activity detector hears speech in the samples, from the first word to the
    /// last; nil if there is none. Throws when the detector is unavailable.
    public var findSpeech: @MainActor ([Float]) async throws -> Range<Int>?
    public var transcribe: @MainActor ([Float]) async throws -> String
    /// Puts the text in the frontmost app.
    public var paste: @MainActor (String) async throws -> Void
    public var report: @MainActor (DictationProblem) -> Void
    /// The Mode every Dictation starts with; nil for the Transcript alone.
    public var defaultMode: @MainActor () -> Mode?
    /// The enabled Modes in the user's order; the first nine get the digits 1–9.
    public var enabledModes: @MainActor () -> [Mode]
    /// The user's Vocabulary, read at every Dictation.
    public var vocabulary: @MainActor () -> Vocabulary
    /// The client for the configured provider; throws when there is none.
    public var chatClient: @MainActor () throws -> ChatClient
    /// Where completed Dictations are kept.
    public var history: History

    public init(
        startRecording: @escaping @MainActor () throws -> Void,
        stopRecording: @escaping @MainActor () async -> [Float],
        findSpeech: @escaping @MainActor ([Float]) async throws -> Range<Int>?,
        transcribe: @escaping @MainActor ([Float]) async throws -> String,
        paste: @escaping @MainActor (String) async throws -> Void,
        report: @escaping @MainActor (DictationProblem) -> Void,
        defaultMode: @escaping @MainActor () -> Mode?,
        enabledModes: @escaping @MainActor () -> [Mode],
        vocabulary: @escaping @MainActor () -> Vocabulary,
        history: History,
        chatClient: @escaping @MainActor () throws -> ChatClient
    ) {
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.findSpeech = findSpeech
        self.transcribe = transcribe
        self.paste = paste
        self.report = report
        self.defaultMode = defaultMode
        self.enabledModes = enabledModes
        self.vocabulary = vocabulary
        self.history = history
        self.chatClient = chatClient
    }
}

/// Runs Dictations from the shortcut events: from the start of recording to the text pasted
/// in the frontmost app. Times are in seconds from any fixed reference (the event timestamps).
@MainActor
@Observable
public final class DictationController {
    public enum Phase: Equatable, Sendable {
        case idle
        case recording
        case processing
    }

    public private(set) var phase: Phase = .idle {
        didSet {
            if phase != .recording { level = 0 }
            if phase != .recording { isModeListVisible = false }
            if phase == .idle {
                mode = nil
                modeChoices = []
            }
        }
    }

    /// The microphone's loudness, 0...1, while recording; 0 otherwise.
    public private(set) var level: Float = 0

    /// The Mode of the Dictation in progress; nil for the Transcript alone.
    public private(set) var mode: Mode?

    /// The Modes the digits 1–9 choose during this Dictation, in order.
    public private(set) var modeChoices: [Mode] = []

    /// Whether the overlay lists the Mode choices: opened and closed with `shift` while
    /// recording, closed by a digit or `Return`.
    public private(set) var isModeListVisible = false

    /// Whether the digit keys belong to Dimmela right now (they choose the Mode) instead of the
    /// frontmost app.
    public var capturesDigits: Bool { phase == .recording }

    /// Whether the arrows and `Return` belong to Dimmela right now (they move through the Mode
    /// list) instead of the frontmost app.
    public var capturesModeListKeys: Bool { isModeListVisible }

    /// Whether `Esc` belongs to Dimmela right now (it cancels the Dictation) instead of the
    /// frontmost app.
    public var capturesEscape: Bool { phase != .idle }

    /// A release this soon after the press turns the Dictation into a Lock.
    public static let lockThreshold: TimeInterval = 0.3

    @ObservationIgnored private let boundaries: DictationBoundaries
    @ObservationIgnored private var pressedAt: TimeInterval = 0
    @ObservationIgnored private var isLocked = false
    /// The current Dictation's processing, cancelled by `Esc`.
    @ObservationIgnored private var processing: Task<Void, Never>?

    public init(boundaries: DictationBoundaries) {
        self.boundaries = boundaries
    }

    /// Starts a Dictation, or ends a Lock. When it ends one, returns once the Dictation is over.
    public func shortcutDown(at time: TimeInterval) async {
        switch phase {
        case .idle:
            do {
                try boundaries.startRecording()
                phase = .recording
                pressedAt = time
                isLocked = false
                mode = boundaries.defaultMode()
                modeChoices = Array(boundaries.enabledModes().prefix(9))
            } catch {
                boundaries.report(.microphoneUnavailable(String(describing: error)))
            }
        case .recording where isLocked:
            await finish()
        case .recording, .processing:
            return
        }
    }

    /// The microphone's loudness from the recorder; kept only while recording.
    public func microphoneLevel(_ level: Float) {
        guard phase == .recording else { return }
        self.level = min(max(level, 0), 1)
    }

    /// Chooses this Dictation's Mode and closes the list: 0 for none, 1–9 for the Mode at that
    /// position. A digit with no Mode is ignored.
    public func modeDigit(_ digit: Int) {
        guard phase == .recording else { return }
        if digit == 0 {
            mode = nil
        } else if modeChoices.indices.contains(digit - 1) {
            mode = modeChoices[digit - 1]
        } else {
            return
        }
        isModeListVisible = false
    }

    /// Opens the Mode list, or closes it if open.
    public func shiftPressed() {
        guard phase == .recording, !modeChoices.isEmpty else { return }
        isModeListVisible.toggle()
    }

    /// Moves the choice up (negative) or down the open list: Transcript first, then the Modes.
    public func moveModeSelection(by offset: Int) {
        guard isModeListVisible else { return }
        let rows: [Mode?] = [nil] + modeChoices
        let current = rows.firstIndex(of: mode) ?? 0
        mode = rows[min(max(current + offset, 0), rows.count - 1)]
    }

    /// Keeps the chosen Mode and closes the list.
    public func confirmModeList() {
        isModeListVisible = false
    }

    /// Ends a Hold, or turns a short tap into a Lock. Returns when the Dictation is over: its
    /// text pasted, the problem reported, or cancelled.
    public func shortcutUp(at time: TimeInterval) async {
        guard phase == .recording, !isLocked else { return }
        if time - pressedAt < Self.lockThreshold {
            isLocked = true
            return
        }
        await finish()
    }

    /// Cancels the Dictation in progress: nothing is pasted.
    public func escape() async {
        switch phase {
        case .idle:
            return
        case .recording:
            _ = await boundaries.stopRecording()
            phase = .idle
        case .processing:
            processing?.cancel()
            processing = nil
            phase = .idle
        }
    }

    private func finish() async {
        phase = .processing
        let mode = mode
        let task = Task { await process(with: mode) }
        processing = task
        await task.value
    }

    /// Once cancelled it leaves everything alone: a new Dictation may already be running.
    private func process(with mode: Mode?) async {
        let recorded = await boundaries.stopRecording()
        // The silence before and after the speech is cut. Without a detector, all of it is kept.
        var samples = recorded
        do {
            guard let speech = try await boundaries.findSpeech(recorded) else { return end() }
            samples = Array(recorded[speech.clamped(to: recorded.indices)])
        } catch {}
        guard !Task.isCancelled else { return }
        let vocabulary = boundaries.vocabulary()
        let transcript: String
        do {
            transcript = Fillers.remove(from: vocabulary.correct(try await boundaries.transcribe(samples)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            guard !Task.isCancelled else { return }
            boundaries.report(.transcriptionFailed(String(describing: error)))
            return end()
        }
        guard !Task.isCancelled else { return }
        guard !transcript.isEmpty else { return end() }

        var text = transcript
        if let mode {
            do {
                text = try await postProcess(transcript, with: mode)
            } catch {
                guard !Task.isCancelled else { return }
                boundaries.report(.postProcessingFailed(Self.describe(error)))
            }
            guard !Task.isCancelled else { return }
        }

        // Kept even if the paste fails: the text can still be copied from the History.
        try? boundaries.history.add(transcript: transcript, text: text, mode: mode, samples: samples)
        do {
            try await boundaries.paste(text + " ")
        } catch {
            boundaries.report(.pasteFailed(String(describing: error)))
        }
        end()
    }

    /// Post-processes a History entry's Transcript with `mode`; nil, with the problem reported,
    /// if it fails.
    public func postProcessAgain(_ entry: HistoryEntry, with mode: Mode) async -> String? {
        do {
            return try await postProcess(entry.transcript, with: mode)
        } catch {
            boundaries.report(.postProcessingAgainFailed(Self.describe(error)))
            return nil
        }
    }

    private func postProcess(_ transcript: String, with mode: Mode) async throws -> String {
        let instructions = [try mode.instructions(), boundaries.vocabulary().promptBlock]
            .compactMap { $0 }.joined(separator: "\n\n")
        return try await boundaries.chatClient().complete([
            ChatMessage(role: .system, content: instructions),
            ChatMessage(role: .user, content: transcript),
        ])
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private func end() {
        guard !Task.isCancelled else { return }
        processing = nil
        phase = .idle
    }
}
