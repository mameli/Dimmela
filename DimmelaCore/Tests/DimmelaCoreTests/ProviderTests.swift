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
