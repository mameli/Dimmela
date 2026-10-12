import DimmelaCore
import Testing

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

@MainActor
@Suite("Hold Dictation")
struct HoldDictationTests {
    let fake = FakeBoundaries()

    @Test("holding the shortcut records; releasing it pastes the Transcript with a trailing space")
    func holdAndRelease() async {
        let controller = fake.controllerWired()

        controller.shortcutDown(shift: false, at: 10)
        #expect(controller.phase == .recording)
        #expect(fake.recordingStarted == 1)

        await controller.shortcutUp(at: 11)
        #expect(fake.recordingStopped == 1)
        #expect(fake.transcribed == [[0.1, 0.2, 0.3]])
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(controller.phase == .idle)
    }

    @Test("the Dictation is processing while the speech model works")
    func processingPhase() async {
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.phaseDuringTranscription == .processing)
    }

    @Test("whitespace around the Transcript is dropped before the trailing space")
    func trimmed() async {
        fake.transcript = .success("  Ciao.\n")
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted == ["Ciao. "])
    }

    @Test("an empty Transcript pastes nothing")
    func emptyTranscript() async {
        fake.transcript = .success("   ")
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems.isEmpty)
        #expect(controller.phase == .idle)
    }

    @Test("a failing speech model is reported and nothing is pasted")
    func transcriptionFails() async {
        fake.transcript = .failure(Failure())
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems == [.transcriptionFailed("boom")])
        #expect(controller.phase == .idle)
    }

    @Test("a failing paste is reported")
    func pasteFails() async {
        fake.pasteError = Failure()
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.problems == [.pasteFailed("boom")])
        #expect(controller.phase == .idle)
    }

    @Test("a microphone that cannot start is reported and no Dictation begins")
    func microphoneFails() async {
        fake.startError = Failure()
        let controller = fake.controllerWired()
        controller.shortcutDown(shift: false, at: 10)
        #expect(controller.phase == .idle)
        #expect(fake.problems == [.microphoneUnavailable("boom")])

        await controller.shortcutUp(at: 11)
        #expect(fake.recordingStopped == 0)
        #expect(fake.pasted.isEmpty)
    }

    @Test("releasing the shortcut without a Dictation does nothing")
    func strayRelease() async {
        let controller = fake.controllerWired()
        await controller.shortcutUp(at: 11)
        #expect(fake.recordingStopped == 0)
        #expect(controller.phase == .idle)
    }
}
