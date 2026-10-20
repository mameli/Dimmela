import DimmelaCore
import Foundation
import Testing

@Suite("Chat client")
struct ChatClientTests {
    let messages = [ChatMessage(role: .system, content: "Clean it up."), ChatMessage(role: .user, content: "Ciao.")]

    func client(
        _ stub: StubTransport, baseURL: String = "https://x.example/v1", reasoning: Provider.ReasoningEffort? = nil,
        extraParameters: String? = nil
    ) -> ChatClient {
        ChatClient(
            baseURL: URL(string: baseURL)!, apiKey: nil, model: "m", reasoning: reasoning, extraParameters: extraParameters,
            transport: stub.send
        )
    }

    @Test("OpenRouter gets the reasoning as an object, every other provider as reasoning_effort", arguments: [
        ("https://openrouter.ai/api/v1", Provider.ReasoningEffort.high, #"{"effort":"high"}"# as String?, nil as String?),
        ("https://openrouter.ai/api/v1", .off, #"{"effort":"none"}"#, nil),
        ("https://api.mistral.ai/v1", .off, nil, "none"),
        ("http://localhost:1234/v1", .medium, nil, "medium"),
    ])
    func reasoning(baseURL: String, effort: Provider.ReasoningEffort, object: String?, field: String?) async throws {
        let stub = StubTransport()
        _ = try await client(stub, baseURL: baseURL, reasoning: effort).complete(messages)

        let body = try #require(stub.sentBody())
        let sentObject = try body["reasoning"].map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }
        #expect(sentObject == object)
        #expect(body["reasoning_effort"] as? String == field)
    }

    @Test("without a reasoning level the request carries neither field", arguments: ["https://openrouter.ai/api/v1", "https://api.mistral.ai/v1"])
    func noReasoning(baseURL: String) async throws {
        let stub = StubTransport()
        _ = try await client(stub, baseURL: baseURL).complete(messages)

        let body = try #require(stub.sentBody())
        #expect(body["reasoning"] == nil)
        #expect(body["reasoning_effort"] == nil)
    }

    @Test("Extra parameters go in the request as written, each key in place of Dimmela's", arguments: [
        // TensorX's DeepSeek: its own key, next to the menu's level.
        ("https://api.tensorx.ai/v1", Provider.ReasoningEffort.high, #"{"chat_template_kwargs":{"thinking":true}}"#,
         #"{"chat_template_kwargs":{"thinking":true},"reasoning_effort":"high"}"#),
        // A level the menu does not have replaces the menu's.
        ("https://api.tensorx.ai/v1", .medium, #"{"reasoning_effort":"xhigh"}"#, #"{"reasoning_effort":"xhigh"}"#),
        // No deep merge: OpenRouter's reasoning object is replaced whole, its effort is not kept.
        ("https://openrouter.ai/api/v1", .low, #"{"reasoning":{"max_tokens":4000}}"#, #"{"reasoning":{"max_tokens":4000}}"#),
        ("http://localhost:1234/v1", nil, "  ", "{}"),
    ] as [(String, Provider.ReasoningEffort?, String, String)])
    func extraParameters(baseURL: String, effort: Provider.ReasoningEffort?, extra: String, expected: String) async throws {
        let stub = StubTransport()
        _ = try await client(stub, baseURL: baseURL, reasoning: effort, extraParameters: extra).complete(messages)

        var body = try #require(stub.sentBody())
        #expect(body.removeValue(forKey: "model") as? String == "m")
        #expect(body.removeValue(forKey: "messages") != nil)
        let rest = try #require(JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary)
        #expect(NSDictionary(dictionary: body) == rest)
    }

    @Test("invalid Extra parameters stop the request before it is sent")
    func invalidExtraParameters() async {
        let stub = StubTransport()
        await #expect(throws: ExtraParameters.Problem.reserved("model")) {
            try await client(stub, extraParameters: #"{"model":"other"}"#).complete(messages)
        }
        #expect(stub.requests.isEmpty)
    }

    @Test("a refused request says what Settings adds to it, not the parameters", arguments: [
        (400, Provider.ReasoningEffort.high, #"{"x":1}"#,
         "The provider answered with error 400: use xhigh. Settings › Post-processing sets Reasoning: High and Extra parameters."),
        (422, .off, "", "The provider answered with error 422: use xhigh. Settings › Post-processing sets Reasoning: Off."),
        (400, nil, #"{"x":1}"#, "The provider answered with error 400: use xhigh. Settings › Post-processing sets Extra parameters."),
        (400, nil, "", "The provider answered with error 400: use xhigh"),
        // Not a refusal of what was sent: nothing added.
        (401, .high, #"{"x":1}"#, "The provider answered with error 401: use xhigh"),
        // The Extra parameters replaced the menu's level: it was not sent, so it is not named.
        (400, .high, #"{"reasoning_effort":"banana"}"#,
         "The provider answered with error 400: use xhigh. Settings › Post-processing sets Extra parameters."),
    ] as [(Int, Provider.ReasoningEffort?, String, String)])
    func refusedWithSettings(status: Int, effort: Provider.ReasoningEffort?, extra: String, expected: String) async {
        let stub = StubTransport()
        stub.status = status
        stub.body = #"{"error":{"message":"use xhigh"}}"#

        do {
            _ = try await client(stub, reasoning: effort, extraParameters: extra).complete(messages)
            Issue.record("no error")
        } catch {
            #expect(error.localizedDescription == expected)
        }
    }

    @Test("on OpenRouter, a reasoning object in the Extra parameters replaces the menu's level, which is not named")
    func openRouterReasoningReplaced() async {
        let stub = StubTransport()
        stub.status = 400
        stub.body = #"{"error":{"message":"bad reasoning"}}"#

        await #expect(throws: ChatClient.Failure.http(status: 400, message: "bad reasoning", hasExtraParameters: true)) {
            try await client(
                stub, baseURL: "https://openrouter.ai/api/v1", reasoning: .high, extraParameters: #"{"reasoning":{"max_tokens":-1}}"#
            ).complete(messages)
        }
    }

    @Test("a long error message is cut at 300 characters, so what Settings sets stays readable", arguments: [
        #"{"error":{"message":"regolo.BadRequestError: "# + String(repeating: "x", count: 400) + #""}}"#,
        "<html>" + String(repeating: "x", count: 400) + "</html>",
    ])
    func longErrorMessage(body: String) async {
        let stub = StubTransport()
        stub.status = 400
        stub.body = body

        do {
            _ = try await client(stub, reasoning: .high).complete(messages)
            Issue.record("no error")
        } catch let ChatClient.Failure.http(_, message, _, _) {
            #expect(message.count == 301)
            #expect(message.hasSuffix("…"))
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test("after a message cut short, what Settings sets follows the ellipsis without a full stop")
    func cutMessageWithSettings() {
        let failure = ChatClient.Failure.http(status: 400, message: "Input should be 'none'…", reasoning: .high)
        #expect(failure.localizedDescription
            == "The provider answered with error 400: Input should be 'none'… Settings › Post-processing sets Reasoning: High.")
    }

    @Test("a reply in chunks (Mistral reasoning) gives the text chunks, not the thinking")
    func chunks() async throws {
        let stub = StubTransport()
        stub.body = #"""
            {"choices":[{"message":{"role":"assistant","content":[
              {"type":"thinking","thinking":[{"type":"text","text":"The user wants it cleaned up."}]},
              {"type":"text","text":"Ciao, "},{"type":"text","text":"tutto bene."}
            ]}}]}
            """#

        #expect(try await client(stub, baseURL: "https://api.mistral.ai/v1").complete(messages) == "Ciao, tutto bene.")
    }

    @Test("reasoning written in the reply between think tags is not part of it", arguments: [
        "<think>\nThe user wants it cleaned up.\n</think>\n\nCiao, tutto bene.",
        "The user wants it cleaned up.\n</think>\nCiao, tutto bene.",
        "<thinking>Fix the punctuation.</thinking>Ciao, tutto bene.",
        // The later closing tag wins, whichever it is.
        "<think>First.</think> More reasoning.</thinking>Ciao, tutto bene.",
    ])
    func thinkTags(content: String) async throws {
        let stub = StubTransport()
        stub.reply = content

        #expect(try await client(stub).complete(messages) == "Ciao, tutto bene.")
    }

    @Test("a reply that is only reasoning is an empty reply")
    func onlyThinking() async {
        let stub = StubTransport()
        stub.reply = "<think>Hmm.</think>\n"

        await #expect(throws: ChatClient.Failure.emptyReply) {
            try await client(stub).complete(messages)
        }
    }
}
