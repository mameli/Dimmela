import DimmelaCore
import Foundation
import Testing

/// What the overlay shows comes from the controller's published state: phase, microphone level
/// and the Mode of the Dictation.
@MainActor
@Suite("Overlay state")
struct OverlayStateTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    @Test("the microphone level is shown only while recording")
    func level() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        controller.microphoneLevel(0.8)
        #expect(controller.level == 0)

        await controller.shortcutDown(shift: false, at: 10)
        controller.microphoneLevel(0.6)
        #expect(controller.level == 0.6)

        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        #expect(controller.level == 0)
        controller.microphoneLevel(0.9)
        #expect(controller.level == 0)

        fake.finishTranscription()
        await release.value
    }

    @Test("the level is clamped between 0 and 1")
    func clamped() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        controller.microphoneLevel(1.7)
        #expect(controller.level == 1)
        controller.microphoneLevel(-0.2)
        #expect(controller.level == 0)
    }

    @Test("the Dictation's Mode is shown while recording and processing, and cleared at the end")
    func mode() async {
        let prompt = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.defaultMode = prompt
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        #expect(controller.mode == nil)

        await controller.shortcutDown(shift: true, at: 10)
        #expect(controller.mode == prompt)

        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        #expect(controller.phase == .processing)
        #expect(controller.mode == prompt)

        fake.finishTranscription()
        await release.value
        #expect(controller.phase == .idle)
        #expect(controller.mode == nil)
    }

    @Test("a Dictation without shift shows no Mode")
    func noMode() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: false, at: 10)
        #expect(controller.mode == nil)
    }

    @Test("Esc clears the Mode and the level")
    func cancel() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        let controller = fake.controllerWired()
        await controller.shortcutDown(shift: true, at: 10)
        controller.microphoneLevel(0.5)
        await controller.escape()
        #expect(controller.mode == nil)
        #expect(controller.level == 0)
    }
}
