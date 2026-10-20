import DimmelaCore
import Foundation
import Testing

@Suite("Provider")
struct ProviderTests {
    @Test("OpenRouter is usable as it comes")
    func openRouter() throws {
        #expect(try Provider.openRouter.validatedBaseURL().absoluteString == "https://openrouter.ai/api/v1")
    }

    @Test("plain HTTP is accepted only for a server on this Mac")
    func plainHTTP() throws {
        _ = try Provider(baseURL: "http://localhost:1234/v1", model: "qwen").validatedBaseURL()
        #expect(throws: Provider.Failure.insecureURL("http://solaris.local:1234/v1")) {
            try Provider(baseURL: "http://solaris.local:1234/v1", model: "qwen").validatedBaseURL()
        }
    }

    @Test("an address and a model are required")
    func incomplete() {
        #expect(throws: Provider.Failure.invalidURL("openrouter.ai")) {
            try Provider(baseURL: "openrouter.ai", model: "x").validatedBaseURL()
        }
        #expect(throws: Provider.Failure.noModel) {
            try Provider(baseURL: "https://openrouter.ai/api/v1", model: " ").validatedBaseURL()
        }
    }
}

@Suite("Extra parameters")
struct ExtraParametersTests {
    @Test("a JSON object; blank means none", arguments: [
        ("", 0), (" \n ", 0), (#"{}"#, 0), (#"{"chat_template_kwargs": {"thinking": true}, "temperature": 0.2}"#, 2),
    ])
    func valid(text: String, count: Int) throws {
        #expect(try ExtraParameters.parse(text).count == count)
    }

    @Test("not a JSON object, or replacing model or messages, is refused", arguments: [
        (#"{"reasoning_effort": "xhigh""#, ExtraParameters.Problem.notJSON),
        (#"{“reasoning_effort”: “xhigh”}"#, .notJSON),
        (#"[{"thinking": true}]"#, .notAnObject),
        ("42", .notAnObject),
        (#"{"model": "other"}"#, .reserved("model")),
        (#"{"messages": []}"#, .reserved("messages")),
    ])
    func invalid(text: String, problem: ExtraParameters.Problem) {
        #expect(throws: problem) { try ExtraParameters.parse(text) }
    }
}
