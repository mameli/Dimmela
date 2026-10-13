import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("History")
struct HistoryTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    private func dictate(_ controller: DictationController, at time: TimeInterval = 10) async {
        await controller.shortcutDown(at: time)
        await controller.shortcutUp(at: time + 1)
    }

    @Test("a Dictation is kept with its Transcript, final text, Mode and audio")
    func entry() async throws {
        let mode = Mode(id: folder.write("clean.md", "Clean up.").path(percentEncoded: false))
        fake.defaultMode = mode
        fake.samples = Array(repeating: 0.25, count: 16_000)
        let controller = fake.controllerWired()
        await dictate(controller)

        let entry = try #require(fake.history.entries.first)
        #expect(entry.transcript == "Ciao, sto provando Dimmela.")
        #expect(entry.text == "Testo rifinito.")
        #expect(entry.mode == mode)
        #expect(entry.modeName == "Clean")
        let audio = try Data(contentsOf: fake.history.audioURL(of: entry))
        #expect(audio.count == 44 + 2 * 16_000)
        #expect(audio.prefix(4) == Data("RIFF".utf8))
    }

    @Test("a Dictation without a Mode keeps the Transcript as its text")
    func transcriptOnly() async throws {
        let controller = fake.controllerWired()
        await dictate(controller)
        let entry = try #require(fake.history.entries.first)
        #expect(entry.text == entry.transcript)
        #expect(entry.mode == nil)
    }

    @Test("only the last 5 Dictations are kept, newest first, and the older ones leave no files")
    func rotation() async throws {
        let controller = fake.controllerWired()
        for index in 1...6 {
            fake.transcript = .success("Dettato \(index).")
            await dictate(controller, at: TimeInterval(index * 10))
        }
        #expect(fake.history.entries.map(\.transcript) == (2...6).reversed().map { "Dettato \($0)." })
        let folders = try FileManager.default.contentsOfDirectory(atPath: fake.historyFolder.url.path(percentEncoded: false))
        #expect(folders.count == 5)
    }

    @Test("the History is read back from disk")
    func persistence() async {
        let controller = fake.controllerWired()
        await dictate(controller)
        let reopened = History(directory: fake.historyFolder.url)
        #expect(reopened.entries == fake.history.entries)
    }

    @Test("cancelled, empty and failed Dictations are not kept")
    func notKept() async {
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.escape()

        fake.transcript = .success(" ")
        await dictate(controller, at: 20)

        fake.transcript = .failure(Failure())
        await dictate(controller, at: 30)

        #expect(fake.history.entries.isEmpty)
    }

    @Test("a Dictation whose paste failed is kept, so the text is not lost")
    func pasteFailed() async {
        fake.pasteError = Failure()
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.history.entries.count == 1)
    }

    @Test("an entry can be Post-processed again with another Mode")
    func again() async throws {
        let controller = fake.controllerWired()
        await dictate(controller)
        let entry = try #require(fake.history.entries.first)
        let other = Mode(id: folder.write("english.md", "Translate.").path(percentEncoded: false))
        fake.provider.reply = "Hi, I'm trying Dimmela."

        let text = await controller.postProcessAgain(entry, with: other)
        #expect(text == "Hi, I'm trying Dimmela.")
        #expect(fake.provider.message(0, "system") == "Translate.")
        #expect(fake.provider.message(0, "user") == "Ciao, sto provando Dimmela.")
        #expect(fake.pasted.count == 1)
    }

    @Test("a failure to Post-process again is reported and gives no text")
    func againFails() async throws {
        let controller = fake.controllerWired()
        await dictate(controller)
        let entry = try #require(fake.history.entries.first)
        fake.provider.status = 503

        let text = await controller.postProcessAgain(entry, with: Mode(id: folder.write("x.md", "X.").path(percentEncoded: false)))
        #expect(text == nil)
        #expect(fake.problems == [.postProcessingAgainFailed("The provider answered with error 503: overloaded")])
    }
}
