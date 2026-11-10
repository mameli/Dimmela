import DimmelaCore
import Foundation
import Testing

@Suite("Provider profiles")
struct ProviderProfileTests {
    @Test("the Provider of 0.1.7 becomes a profile named after its server", arguments: [
        ("https://openrouter.ai/api/v1", "OpenRouter"),
        ("http://localhost:1234/v1", "LM Studio"),
        ("http://localhost:11434/v1", "Ollama"),
        ("https://api.mistral.ai/v1", "Mistral"),
        ("https://llm.example.com/v1", "llm.example.com"),
        ("", "Provider"),
    ])
    func migration(baseURL: String, name: String) {
        let provider = Provider(baseURL: baseURL, model: "m", reasoning: .low, extraParameters: #"{"x":1}"#)
        let profile = ProviderProfile.migrating(provider)
        #expect(profile.name == name)
        #expect(profile.provider == provider)
    }

    @Test("an empty name shows what the address says")
    func displayName() {
        #expect(ProviderProfile(name: " ", provider: .openRouter).displayName == "OpenRouter")
        #expect(ProviderProfile(name: "", provider: Provider(baseURL: "", model: "")).displayName == "New Profile")
        #expect(ProviderProfile(name: "Work", provider: .openRouter).displayName == "Work")
    }

    @Test("a preset's copy has an identifier of its own")
    func presetCopy() {
        let preset = ProviderProfile.presets[0]
        let copy = preset.copy()
        #expect(copy.id != preset.id)
        #expect(copy.provider == preset.provider)
    }

    @Test("the first profile added is selected; removing the selected one selects the first left")
    func selection() {
        var profiles = ProviderProfiles()
        #expect(profiles.selected == nil)
        let a = ProviderProfile(name: "A", provider: .openRouter)
        let b = ProviderProfile(name: "B", provider: .openRouter)
        profiles.add(a)
        profiles.add(b)
        #expect(profiles.selected == a)
        profiles.selectedID = b.id
        #expect(profiles.selected == b)
        profiles.remove(b.id)
        #expect(profiles.selected == a)
        profiles.remove(a.id)
        #expect(profiles.selected == nil)
        #expect(profiles.selectedID == nil)
    }

    @Test("a selection that no longer exists falls back to the first profile")
    func staleSelection() {
        let a = ProviderProfile(name: "A", provider: .openRouter)
        #expect(ProviderProfiles(all: [a], selectedID: UUID()).selected == a)
    }

    @Test("profiles move as a list does")
    func move() {
        let names = ["A", "B", "C", "D"]
        var profiles = ProviderProfiles(all: names.map { ProviderProfile(name: $0, provider: .openRouter) })
        profiles.move(fromOffsets: [0], toOffset: 3)
        #expect(profiles.all.map(\.name) == ["B", "C", "A", "D"])
        profiles.move(fromOffsets: [3], toOffset: 0)
        #expect(profiles.all.map(\.name) == ["D", "B", "C", "A"])
    }

    @Test("saved as one string and read back the same")
    func rawValue() throws {
        let a = ProviderProfile(name: "A", provider: Provider(baseURL: "https://x.example/v1", model: "m", reasoning: .high))
        let profiles = ProviderProfiles(all: [a], selectedID: a.id)
        #expect(ProviderProfiles(rawValue: profiles.rawValue) == profiles)
        #expect(ProviderProfiles(rawValue: "not json") == nil)
    }

    @Test("the chain is the profile in use, then the fallback profiles in the list's order")
    func chain() {
        let a = ProviderProfile(name: "A", provider: .openRouter, isFallback: true)
        let b = ProviderProfile(name: "B", provider: .openRouter)
        let c = ProviderProfile(name: "C", provider: .openRouter, isFallback: true)
        #expect(ProviderProfiles(all: [a, b, c], selectedID: b.id).chain.map(\.name) == ["B", "A", "C"])
        #expect(ProviderProfiles(all: [a, b, c], selectedID: a.id).chain.map(\.name) == ["A", "C"])
        #expect(ProviderProfiles().chain.isEmpty)
    }

    @Test("a profile saved before fallbacks existed is not one")
    func oldProfile() throws {
        let json = #"{"id":"6F1C2D3E-0000-4000-8000-000000000001","name":"A","provider":{"baseURL":"https://x.example/v1","model":"m"}}"#
        let profile = try JSONDecoder().decode(ProviderProfile.self, from: Data(json.utf8))
        #expect(!profile.isFallback)
    }
}
