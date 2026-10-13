import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("Voice activity detection")
struct SpeechDetectionTests {
    let fake = FakeBoundaries()

    private func dictate() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
    }

    @Test("silence before and after the speech is cut before transcribing, and the History keeps the cut audio")
    func trimmed() async throws {
        fake.samples = [0, 0, 0.4, 0.5, 0.3, 0, 0]
        fake.findSpeech = { _ in 2..<5 }
        await dictate()
        #expect(fake.transcribed == [[0.4, 0.5, 0.3]])
        #expect(fake.pasted.count == 1)
        let entry = try #require(fake.history.entries.first)
        let audio = try Data(contentsOf: fake.history.audioURL(of: entry))
        #expect(audio.count == 44 + 2 * 3)
    }

    @Test("a Dictation with no speech transcribes nothing, pastes nothing and is not kept")
    func noSpeech() async {
        fake.findSpeech = { _ in nil }
        await dictate()
        #expect(fake.transcribed.isEmpty)
        #expect(fake.pasted.isEmpty)
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.problems.isEmpty)
        #expect(fake.history.entries.isEmpty)
    }

    @Test("if the detector fails, all the audio is transcribed")
    func detectorFails() async {
        fake.findSpeech = { _ in throw Failure() }
        await dictate()
        #expect(fake.transcribed == [[0.1, 0.2, 0.3]])
        #expect(fake.pasted.count == 1)
        #expect(fake.problems.isEmpty)
    }
}
