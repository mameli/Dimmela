import DimmelaCore

/// Stands in for the microphone, the speech model and the paste: records what the controller
/// asked of them and returns prepared answers.
@MainActor
final class FakeBoundaries {
    var samples: [Float] = [0.1, 0.2, 0.3]
    var transcript: Result<String, Error> = .success("Ciao, sto provando Dimmela.")
    var startError: Error?
    var pasteError: Error?

    private(set) var recordingStarted = 0
    private(set) var recordingStopped = 0
    private(set) var transcribed: [[Float]] = []
    private(set) var pasted: [String] = []
    private(set) var problems: [DictationProblem] = []
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
            report: { [unowned self] problem in problems.append(problem) }
        ))
        self.controller = controller
        return controller
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
