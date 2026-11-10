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

    @Test("a provider error that does not pass pastes the Transcript and reports the problem")
    func providerError() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.provider.status = 503
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.provider.requests.count == 3)
        #expect(fake.pauses.all == ChatClient.retryWaits)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("The provider answered with error 503: overloaded")])
        #expect(fake.records.map(\.attempts) == [3])
    }

    @Test("a busy provider is asked again: the answer is pasted, the overlay said Dimmela was retrying, the log counts the requests")
    func retriedUntilAnswered() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.provider.statuses = [429]
        fake.provider.reply = "Ciao, sto provando Dimmela!"
        let controller = fake.controllerWired()
        let seen = Seen()
        fake.pauses.whileWaiting = { [controller] in await seen.note(controller.retries) }

        await dictate(controller)

        #expect(fake.provider.requests.count == 2)
        #expect(seen.retries == [1])
        #expect(controller.retries == 0)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela! "])
        #expect(fake.problems.isEmpty)
        #expect(fake.records.map(\.attempts) == [2])
        #expect(fake.records.first?.text == "Ciao, sto provando Dimmela!")
    }

    @Test("a refused request is not sent again", arguments: [400, 401, 404])
    func refusedOnce(status: Int) async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.provider.status = status
        let controller = fake.controllerWired()
        await dictate(controller)
        #expect(fake.provider.requests.count == 1)
        #expect(fake.pauses.all.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
    }

    @Test("Esc while waiting to retry cancels the Dictation: nothing pasted, nothing sent again, nothing logged")
    func escapeWhileRetrying() async {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.provider.status = 503
        let controller = fake.controllerWired()
        fake.pauses.whileWaiting = { [controller] in await controller.escape() }

        await dictate(controller)

        #expect(fake.provider.requests.count == 1)
        #expect(controller.phase == .idle)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems.isEmpty)
        #expect(fake.records.isEmpty)
    }

    @Test("Post-processing again from the History retries too, without touching the overlay")
    func againRetries() async throws {
        let mode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        let controller = fake.controllerWired()
        await dictate(controller)
        let entry = try #require(fake.history.entries.first)
        fake.provider.statuses = [502]
        fake.provider.reply = "Di nuovo."

        let text = await controller.postProcessAgain(entry, with: mode)

        #expect(text == "Di nuovo.")
        #expect(fake.provider.requests.count == 2)
        #expect(controller.retries == 0)
        #expect(fake.records.last?.attempts == 2)
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

    @Test("each Post-processing is recorded with what went in, what came out and with what")
    func recorded() async throws {
        let file = folder.write("prompt.md", "Clean up the transcript.")
        fake.defaultMode = Mode(id: file.path(percentEncoded: false))
        fake.vocabulary = Vocabulary(text: "- Claude")
        fake.provider.reply = "Ciao, sto provando Dimmela!"
        let controller = fake.controllerWired()

        await dictate(controller)

        let record = try #require(fake.records.first)
        #expect(fake.records.count == 1)
        #expect(record.mode == "Prompt")
        #expect(record.modeFile == file.path(percentEncoded: false))
        #expect(record.model == "anthropic/claude-haiku-5.5")
        #expect(record.reasoning == "low")
        #expect(!record.hasExtraParameters)
        #expect(!record.isAgain)
        #expect(record.transcript == "Ciao, sto provando Dimmela.")
        #expect(record.text == "Ciao, sto provando Dimmela!")
        #expect(record.error == nil)
    }

    @Test("the prompt version follows the Mode's instructions, not the Vocabulary")
    func promptVersion() async throws {
        let file = folder.write("prompt.md", "First version.")
        fake.defaultMode = Mode(id: file.path(percentEncoded: false))
        let controller = fake.controllerWired()
        await dictate(controller)
        fake.vocabulary = Vocabulary(text: "- Claude")
        await dictate(controller)
        folder.write("prompt.md", "Second version.")
        await dictate(controller)

        let versions = fake.records.map(\.promptVersion)
        #expect(versions.count == 3)
        #expect(versions[0] == versions[1])
        #expect(versions[1] != versions[2])
        #expect(versions[0].count == 8)
    }

    @Test("a failed Post-processing is recorded with its error; Post-processing again is marked")
    func recordedFailureAndAgain() async throws {
        let mode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        fake.defaultMode = mode
        fake.provider.status = 503
        let controller = fake.controllerWired()
        await dictate(controller)

        fake.provider.status = 200
        let entry = try #require(fake.history.entries.first)
        _ = await controller.postProcessAgain(entry, with: mode)

        #expect(fake.records.map(\.text) == [nil, "Testo rifinito."])
        #expect(fake.records.map(\.error) == ["The provider answered with error 503: overloaded", nil])
        #expect(fake.records.map(\.isAgain) == [false, true])
        #expect(fake.records.map(\.dictationID) == [entry.id, entry.id])
    }

    @Test("nothing is recorded without a Mode, or when the Mode's file is gone")
    func notRecorded() async {
        let controller = fake.controllerWired()
        await dictate(controller)
        fake.defaultMode = Mode(id: folder.url.appending(path: "gone.md").path(percentEncoded: false))
        await dictate(controller)
        #expect(fake.records.isEmpty)
    }

    @Test("a record is one line of JSON that reads back the same")
    func jsonLine() throws {
        let client = ChatClient(
            baseURL: URL(string: "https://x.example/v1")!, apiKey: nil, model: "m", extraParameters: #"{"x":1}"#,
            transport: StubTransport().send
        )
        let record = PostProcessingRecord(
            dictationID: UUID(), date: Date(timeIntervalSince1970: 1_800_000_000), mode: Mode(id: "/modes/email.md"), instructions: "Write an email.",
            client: client, isAgain: false, transcript: "Ciao\n\"Marco\"", text: "Hi Marco,", error: nil, seconds: 1.234
        )
        let line = record.jsonLine
        #expect(!line.contains("\n"))
        #expect(line.contains(#""modeFile":"/modes/email.md""#))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let read = try decoder.decode(PostProcessingRecord.self, from: Data(line.utf8))
        #expect(read == record)
        #expect(read.hasExtraParameters)
        #expect(read.seconds == 1.23)
    }
}

@MainActor
private final class Seen {
    private(set) var retries: [Int] = []
    func note(_ value: Int) { retries.append(value) }
}
