import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("Fallback to the next Provider profile")
struct FallbackTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    private func dictate(_ controller: DictationController) async {
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
    }

    private func withMode() {
        fake.defaultMode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
    }

    @Test("when the profile in use still fails after its Retries, the next one answers and the user is told")
    func fallsBack() async {
        withMode()
        fake.provider.status = 503
        let mistral = StubTransport()
        mistral.reply = "Dalla riserva."
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(fake.provider.requests.count == 3)
        #expect(mistral.requests.count == 1)
        #expect(mistral.message(0, "system") == "Clean up.")
        #expect(mistral.message(0, "user") == fake.provider.message(0, "user"))
        #expect(fake.pasted == ["Dalla riserva. "])
        #expect(fake.problems == [.postProcessingFellBack(
            failed: "OpenRouter", detail: "The provider answered with error 503: overloaded", answeredBy: "Mistral"
        )])
        #expect(fake.records.map(\.profile) == ["OpenRouter", "Mistral"])
        #expect(fake.records.map(\.text) == [nil, "Dalla riserva."])
        #expect(controller.fallbackProfile == nil)
        #expect(fake.history.entries.first?.text == "Dalla riserva.")
    }

    @Test("a coding agent's CLI is a profile like the others: signed out, the next profile answers")
    func agentFallsBack() async throws {
        withMode()
        let claude = try FakeCLI(.claude, [.init(pattern: "-p*", script: FakeCLI.prints("""
            {"type":"result","is_error":true,"subtype":"success","result":"Not logged in · Please run /login"}
            """, exit: 1))])
        fake.inUse = NamedChatClient(name: "Claude Code") { claude.runner().client(for: AgentCLI.claude.profile()) }
        let mistral = StubTransport()
        mistral.reply = "Dalla riserva."
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(claude.calls.count == 1)
        #expect(claude.calls.first?.input.contains("<instructions>\nClean up.\n</instructions>") == true)
        #expect(fake.pasted == ["Dalla riserva. "])
        #expect(fake.problems == [.postProcessingFellBack(
            failed: "Claude Code", detail: AgentCLI.Failure.notSignedIn(.claude).localizedDescription, answeredBy: "Mistral"
        )])
    }

    @Test("a failure a different provider can fix falls back at once, with no Retry", arguments: [400, 401, 402, 404])
    func refusedFallsBack(status: Int) async {
        withMode()
        fake.provider.status = status
        let mistral = StubTransport()
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(fake.provider.requests.count == 1)
        #expect(mistral.requests.count == 1)
        #expect(fake.pasted == ["Testo rifinito. "])
    }

    @Test("a profile that cannot be built is skipped")
    func unbuildableProfile() async {
        withMode()
        fake.chatClientError = Failure()
        fake.fallbacks = [("Mistral", StubTransport())]
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(fake.pasted == ["Testo rifinito. "])
        #expect(fake.problems == [.postProcessingFellBack(failed: "OpenRouter", detail: "boom", answeredBy: "Mistral")])
    }

    @Test("when every profile fails the Transcript is pasted with the first profile's problem")
    func allFail() async {
        withMode()
        fake.provider.status = 401
        let mistral = StubTransport()
        mistral.status = 500
        let ollama = StubTransport()
        ollama.status = 404
        fake.fallbacks = [("Mistral", mistral), ("Ollama", ollama)]
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(mistral.requests.count == 3)
        #expect(ollama.requests.count == 1)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("The provider answered with error 401: overloaded")])
        #expect(fake.records.map(\.profile) == ["OpenRouter", "Mistral", "Ollama"])
    }

    @Test("past the time budget no fallback is started")
    func budget() async {
        withMode()
        fake.provider.status = 401
        let mistral = StubTransport()
        fake.fallbacks = [("Mistral", mistral)]
        fake.fallbackBudget = .zero
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(mistral.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("The provider answered with error 401: overloaded")])
    }

    @Test("the overlay names the fallback profile while it is tried, and its Retries start again")
    func overlay() async {
        withMode()
        fake.provider.status = 503
        let mistral = StubTransport()
        mistral.statuses = [503]
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()
        let seen = Seen()
        fake.pauses.whileWaiting = { [controller] in await seen.note(controller.fallbackProfile, controller.retries) }

        await dictate(controller)

        #expect(seen.states.map(\.profile) == [nil, nil, "Mistral"])
        #expect(seen.states.map(\.retries) == [1, 2, 1])
        #expect(fake.pasted == ["Testo rifinito. "])
    }

    @Test("Esc while the profile in use is retried tries no fallback")
    func escape() async {
        withMode()
        fake.provider.status = 503
        let mistral = StubTransport()
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()
        fake.pauses.whileWaiting = { [controller] in await controller.escape() }

        await dictate(controller)

        #expect(mistral.requests.isEmpty)
        #expect(fake.pasted.isEmpty)
        #expect(fake.problems.isEmpty)
    }

    @Test("with no profile at all, Post-processing says so and the Transcript is pasted")
    func noProfile() async {
        withMode()
        fake.hasNoProfile = true
        let controller = fake.controllerWired()

        await dictate(controller)

        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems == [.postProcessingFailed("No Provider profile: add one in Settings › Post-processing.")])
    }

    @Test("Post-processing again falls back too")
    func again() async throws {
        let mode = Mode(id: folder.write("prompt.md", "Clean up.").path(percentEncoded: false))
        let mistral = StubTransport()
        mistral.reply = "Di nuovo."
        fake.fallbacks = [("Mistral", mistral)]
        let controller = fake.controllerWired()
        await dictate(controller)
        let entry = try #require(fake.history.entries.first)
        fake.provider.status = 401

        #expect(await controller.postProcessAgain(entry, with: mode) == "Di nuovo.")
        #expect(fake.problems.count == 1)
    }
}

@MainActor
private final class Seen {
    private(set) var states: [(profile: String?, retries: Int)] = []
    func note(_ profile: String?, _ retries: Int) { states.append((profile, retries)) }
}
