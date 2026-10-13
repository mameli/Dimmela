import Foundation
import Observation

/// What went wrong in a Dictation, for the user to see. The detail is the underlying error.
public enum DictationProblem: Equatable, Sendable {
    case microphoneUnavailable(String)
    case transcriptionFailed(String)
    case pasteFailed(String)
    /// The Transcript was pasted instead of the LLM's answer.
    case postProcessingFailed(String)
}

/// The platform pieces a Dictation needs, injected so the controller can be driven in tests.
public struct DictationBoundaries {
    public var startRecording: @MainActor () throws -> Void
    /// Stops the microphone and returns what it heard: 16 kHz mono samples.
    public var stopRecording: @MainActor () async -> [Float]
    public var transcribe: @MainActor ([Float]) async throws -> String
    /// Puts the text in the frontmost app.
    public var paste: @MainActor (String) async throws -> Void
    public var report: @MainActor (DictationProblem) -> Void
    /// The Mode `shift+fn+space` applies, if the user chose one.
    public var defaultMode: @MainActor () -> Mode?
    /// The enabled Modes in the user's order; the first nine get the digits 1–9.
    public var enabledModes: @MainActor () -> [Mode]
    /// The client for the configured provider; throws when there is none.
    public var chatClient: @MainActor () throws -> ChatClient

    public init(
        startRecording: @escaping @MainActor () throws -> Void,
        stopRecording: @escaping @MainActor () async -> [Float],
        transcribe: @escaping @MainActor ([Float]) async throws -> String,
        paste: @escaping @MainActor (String) async throws -> Void,
        report: @escaping @MainActor (DictationProblem) -> Void,
        defaultMode: @escaping @MainActor () -> Mode?,
        enabledModes: @escaping @MainActor () -> [Mode],
        chatClient: @escaping @MainActor () throws -> ChatClient
    ) {
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.transcribe = transcribe
        self.paste = paste
        self.report = report
        self.defaultMode = defaultMode
        self.enabledModes = enabledModes
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
            if phase != .recording {
                showsModeListForDigit = false
                isShiftDown = false
            }
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

    /// Whether the overlay lists the Mode choices: while `shift` is held, or once a digit was
    /// pressed, during recording.
    public var isModeListVisible: Bool {
        phase == .recording && !modeChoices.isEmpty && (isShiftDown || showsModeListForDigit)
    }

    /// Whether the digit keys belong to Dimmela right now (they choose the Mode) instead of the
    /// frontmost app.
    public var capturesDigits: Bool { phase == .recording }

    private var isShiftDown = false
    private var showsModeListForDigit = false

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
    public func shortcutDown(shift: Bool, at time: TimeInterval) async {
        switch phase {
        case .idle:
            do {
                try boundaries.startRecording()
                phase = .recording
                pressedAt = time
                isLocked = false
                mode = shift ? boundaries.defaultMode() : nil
                modeChoices = Array(boundaries.enabledModes().prefix(9))
                isShiftDown = shift
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

    /// Chooses this Dictation's Mode: 0 for none, 1–9 for the Mode at that position. A digit with
    /// no Mode is ignored.
    public func modeDigit(_ digit: Int) {
        guard phase == .recording else { return }
        showsModeListForDigit = true
        if digit == 0 {
            mode = nil
        } else if modeChoices.indices.contains(digit - 1) {
            mode = modeChoices[digit - 1]
        }
    }

    public func shiftChanged(isDown: Bool) {
        guard phase == .recording else { return }
        isShiftDown = isDown
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
        let samples = await boundaries.stopRecording()
        let transcript: String
        do {
            transcript = try await boundaries.transcribe(samples)
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

        do {
            try await boundaries.paste(text + " ")
        } catch {
            boundaries.report(.pasteFailed(String(describing: error)))
        }
        end()
    }

    private func postProcess(_ transcript: String, with mode: Mode) async throws -> String {
        let instructions = try mode.instructions()
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
