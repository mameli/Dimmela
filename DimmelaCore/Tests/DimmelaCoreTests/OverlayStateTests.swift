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

    /// Feeds blocks of the given loudness, as the recorder does about twelve times a second.
    private func hear(_ controller: DictationController, _ decibels: Float, times: Int = 1) {
        for _ in 0..<times { controller.microphoneLoudness(decibels) }
    }

    @Test("the level moves only while recording")
    func level() async {
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        hear(controller, -20)
        #expect(controller.level == 0)

        await controller.shortcutDown(at: 10)
        hear(controller, -60, times: 10)
        hear(controller, -25)
        #expect(controller.level > 0.5)

        let release = Task { await controller.shortcutUp(at: 11) }
        await fake.untilTranscribing()
        #expect(controller.level == 0)
        hear(controller, -20)
        #expect(controller.level == 0)

        fake.finishTranscription()
        await release.value
    }

    @Test("a quiet microphone moves the bars as much as a loud one", arguments: [
        (noise: Float(-66), speech: Float(-53)),  // MacBook built-in microphone, measured
        (noise: Float(-60), speech: Float(-25)),  // headset, measured
    ])
    func adaptive(noise: Float, speech: Float) async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        hear(controller, noise, times: 12)
        #expect(controller.level < 0.15)
        hear(controller, speech)
        #expect(controller.level > 0.7)
        hear(controller, (noise + speech) / 2)
        #expect(controller.level > 0.2 && controller.level < 0.8)
    }

    @Test("background noise alone stays near zero")
    func noise() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        var levels: [Float] = []
        for index in 0..<60 {
            controller.microphoneLoudness(index % 2 == 0 ? -66 : -64)
            levels.append(controller.level)
        }
        #expect(levels.dropFirst(5).allSatisfy { $0 < 0.25 })
    }

    @Test("the level stays between 0 and 1")
    func clamped() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        hear(controller, 0)
        #expect(controller.level <= 1)
        hear(controller, -200)
        #expect(controller.level == 0)
    }

    @Test("each Dictation measures its microphone afresh")
    func afresh() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        hear(controller, -60, times: 12)
        hear(controller, -20, times: 3)
        await controller.shortcutUp(at: 11)

        await controller.shortcutDown(at: 20)
        hear(controller, -66, times: 12)
        hear(controller, -53)
        #expect(controller.level > 0.7)
    }

    @Test("the Dictation's Mode is shown while recording and processing, and cleared at the end")
    func mode() async {
        let prompt = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.defaultMode = prompt
        fake.holdsTranscription = true
        let controller = fake.controllerWired()
        #expect(controller.mode == nil)

        await controller.shortcutDown(at: 10)
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

    @Test("a Dictation with no Default Mode shows no Mode")
    func noMode() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        #expect(controller.mode == nil)
    }

    @Test("Esc clears the Mode and the level")
    func cancel() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        hear(controller, -60, times: 5)
        hear(controller, -30)
        await controller.escape()
        #expect(controller.mode == nil)
        #expect(controller.level == 0)
    }
}
