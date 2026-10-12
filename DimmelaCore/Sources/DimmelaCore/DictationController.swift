import Foundation
import Observation

/// What went wrong in a Dictation, for the user to see. The detail is the underlying error.
public enum DictationProblem: Equatable, Sendable {
    case microphoneUnavailable(String)
    case transcriptionFailed(String)
    case pasteFailed(String)
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

    public init(
        startRecording: @escaping @MainActor () throws -> Void,
        stopRecording: @escaping @MainActor () async -> [Float],
        transcribe: @escaping @MainActor ([Float]) async throws -> String,
        paste: @escaping @MainActor (String) async throws -> Void,
        report: @escaping @MainActor (DictationProblem) -> Void
    ) {
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.transcribe = transcribe
        self.paste = paste
        self.report = report
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

    public private(set) var phase: Phase = .idle

    @ObservationIgnored private let boundaries: DictationBoundaries

    public init(boundaries: DictationBoundaries) {
        self.boundaries = boundaries
    }

    public func shortcutDown(shift: Bool, at time: TimeInterval) {
        guard phase == .idle else { return }
        do {
            try boundaries.startRecording()
            phase = .recording
        } catch {
            boundaries.report(.microphoneUnavailable(String(describing: error)))
        }
    }

    /// Returns when the Dictation is over: its text pasted, or the problem reported.
    public func shortcutUp(at time: TimeInterval) async {
        guard phase == .recording else { return }
        phase = .processing
        defer { phase = .idle }

        let samples = await boundaries.stopRecording()
        let transcript: String
        do {
            transcript = try await boundaries.transcribe(samples)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            boundaries.report(.transcriptionFailed(String(describing: error)))
            return
        }
        guard !transcript.isEmpty else { return }

        do {
            try await boundaries.paste(transcript + " ")
        } catch {
            boundaries.report(.pasteFailed(String(describing: error)))
        }
    }
}
