import DimmelaCore
import Testing

@MainActor
@Suite("Lock and Esc")
struct LockAndEscapeTests {
    let fake = FakeBoundaries()

    @Test("a tap under 300 ms keeps recording; the next press ends the Lock and pastes")
    func lock() async {
        let controller = fake.controllerWired()

        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 10.29)
        #expect(controller.phase == .recording)
        #expect(fake.recordingStopped == 0)

        await controller.shortcutDown(at: 25)
        #expect(fake.recordingStopped == 1)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(controller.phase == .idle)
    }

    @Test("releasing the press that ended a Lock starts nothing")
    func lockEndingRelease() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 10.1)
        await controller.shortcutDown(at: 25)
        await controller.shortcutUp(at: 25.1)

        #expect(fake.recordingStarted == 1)
        #expect(fake.pasted.count == 1)
        #expect(controller.phase == .idle)
    }

    @Test("a release at exactly 300 ms ends a Hold")
    func threshold() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 10.3)
        #expect(fake.pasted.count == 1)
        #expect(controller.phase == .idle)
    }

    @Test("Esc while recording stops the microphone and pastes nothing")
    func escapeWhileHolding() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.escape()

        #expect(fake.recordingStopped == 1)
        #expect(fake.transcribed.isEmpty)
        #expect(controller.phase == .idle)

        // The shortcut is released after Esc: nothing more happens.
        await controller.shortcutUp(at: 12)
        #expect(fake.pasted.isEmpty)
        #expect(fake.recordingStopped == 1)
    }

    @Test("Esc during a Lock cancels it")
    func escapeDuringLock() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 10.1)
        await controller.escape()

        #expect(fake.transcribed.isEmpty)
        #expect(controller.phase == .idle)
    }

    @Test("Esc while processing pastes nothing, even when the speech model answers later")
    func escapeWhileProcessing() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()

        await controller.escape()
        #expect(controller.phase == .idle)

        fake.finishTranscription()
        await release.value
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems.isEmpty)
        #expect(controller.phase == .idle)
    }

    @Test("a Dictation started after Esc is not disturbed by the cancelled one")
    func newDictationAfterCancel() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        let cancelled = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        await controller.escape()

        await controller.shortcutDown(at: 12)
        fake.finishTranscription()
        await cancelled.value
        #expect(controller.phase == .recording)
        #expect(fake.pasted.isEmpty)
    }

    @Test("Esc reaches the frontmost app unless a Dictation is in progress")
    func escapeCapture() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        #expect(!controller.capturesEscape)

        await controller.shortcutDown(at: 10)
        #expect(controller.capturesEscape)

        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        #expect(controller.capturesEscape)

        fake.finishTranscription()
        await release.value
        #expect(!controller.capturesEscape)
    }

    @Test("Esc with no Dictation does nothing")
    func strayEscape() async {
        let controller = fake.controllerWired()
        await controller.escape()
        #expect(fake.recordingStopped == 0)
        #expect(controller.phase == .idle)
    }

    @Test("the shortcut is ignored while a Dictation is processing")
    func ignoredWhileProcessing() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()

        await controller.shortcutDown(at: 11.5)
        await controller.shortcutUp(at: 12)
        #expect(fake.recordingStarted == 1)

        fake.finishTranscription()
        await release.value
        #expect(fake.pasted.count == 1)
        #expect(controller.phase == .idle)
    }
}
