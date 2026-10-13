import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("Post-processing")
struct PostProcessingTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    private func dictate(_ controller: DictationController) async {
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
    }

    @Test("a Dictation sends the Transcript with the Default Mode and pastes the answer")
    func defaultMode() async throws {
        let file = folder.write("prompt.md", "Clean up the transcript.")
        fake.defaultMode = Mode(id: file.path(percentEncoded: false))
        fake.provider.reply = "Ciao, sto provando Dimmela!"
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(fake.provider.requests.count == 1)
        let request = fake.provider.requests[0]
        #expect(request.url?.absoluteString == "https://openrouter.ai/api/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(fake.provider.message(0, "system") == "Clean up the transcript.")
        #expect(fake.provider.message(0, "user") == "Ciao, sto provando Dimmela.")
        #expect(fake.pasted == ["Ciao, sto provando Dimmela! "])
        #expect(fake.problems.isEmpty)
    }

    @Test("with no Default Mode, a Dictation pastes the Transcript and calls no LLM")
    func noDefaultMode() async {
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems.isEmpty)
    }

    @Test("Handy's ${output} placeholder is dropped: the Transcript travels as the user message")
    func handyPlaceholder() async {
        let file = folder.write("prompt.md", "Clean it up.\n\nTranscript:\n${output}\n")
        fake.defaultMode = Mode(id: file.path(percentEncoded: false))
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.provider.message(0, "system") == "Clean it up.\n\nTranscript:")
        #expect(fake.provider.message(0, "user") == "Ciao, sto provando Dimmela.")
    }

    @Test("the prompt file is read at every Dictation")
    func rereadEveryTime() async {
        let file = folder.write("prompt.md", "First version.")
        fake.defaultMode = Mode(id: file.path(percentEncoded: false))
        let controller = fake.controllerWired()
        await dictate(controller)
        folder.write("prompt.md", "Second version.")
        await dictate(controller)
        #expect(fake.provider.message(1, "system") == "Second version.")
    }

    @Test("a provider error pastes the Transcript and reports the problem")
    func providerError() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.provider.status = 503
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("The provider answered with error 503: overloaded")])
    }

    @Test("a Mode whose file is gone pastes the Transcript and reports the problem")
    func missingFile() async {
        fake.defaultMode = Mode(id: folder.url.appending(path: "gone.md").path(percentEncoded: false))
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems.count == 1)
    }

    @Test("an unconfigured provider pastes the Transcript and reports the problem")
    func unconfigured() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.chatClientError = Failure()
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("boom")])
    }

    @Test("the Default Mode is the one chosen when the Dictation starts")
    func modeFixedAtStart() async {
        let first = folder.write("first.md", "First.")
        let second = folder.write("second.md", "Second.")
        fake.defaultMode = Mode(id: first.path(percentEncoded: false))
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        fake.defaultMode = Mode(id: second.path(percentEncoded: false))
        await controller.shortcutUp(at: 11)
        #expect(fake.provider.message(0, "system") == "First.")
    }
}
