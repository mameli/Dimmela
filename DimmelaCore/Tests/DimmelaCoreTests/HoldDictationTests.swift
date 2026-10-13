import DimmelaCore
import Testing

@MainActor
@Suite("Hold Dictation")
struct HoldDictationTests {
    let fake = FakeBoundaries()

    @Test("holding the shortcut records; releasing it pastes the Transcript with a trailing space")
    func holdAndRelease() async {
        let controller = fake.controllerWired()

        await controller.shortcutDown(at: 10)
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
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.phaseDuringTranscription == .processing)
    }

    @Test("whitespace around the Transcript is dropped before the trailing space")
    func trimmed() async {
        fake.transcript = .success("  Ciao.\n")
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted == ["Ciao. "])
    }

    @Test("an empty Transcript pastes nothing")
    func emptyTranscript() async {
        fake.transcript = .success("   ")
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems.isEmpty)
        #expect(controller.phase == .idle)
    }

    @Test("a failing speech model is reported and nothing is pasted")
    func transcriptionFails() async {
        fake.transcript = .failure(Failure())
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems == [.transcriptionFailed("boom")])
        #expect(controller.phase == .idle)
    }

    @Test("a failing paste is reported")
    func pasteFails() async {
        fake.pasteError = Failure()
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        #expect(fake.problems == [.pasteFailed("boom")])
        #expect(controller.phase == .idle)
    }

    @Test("a microphone that cannot start is reported and no Dictation begins")
    func microphoneFails() async {
        fake.startError = Failure()
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
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
