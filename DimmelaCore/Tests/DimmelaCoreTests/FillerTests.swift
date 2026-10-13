import DimmelaCore
import Testing

@MainActor
@Suite("Fillers")
struct FillerTests {
    let fake = FakeBoundaries()

    private func pasted(after transcript: String) async -> [String] {
        fake.transcript = .success(transcript)
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        return fake.pasted
    }

    @Test("Fillers inside a sentence go, with their comma", arguments: [
        ("Allora, ehm, volevo dire una cosa.", "Allora, volevo dire una cosa."),
        ("Domani uhm vado a Milano.", "Domani vado a Milano."),
        ("Ho visto, mmh, tre film.", "Ho visto, tre film."),
        ("Sì, eh, è vero.", "Sì, è vero."),
        ("Ok, uhm, I think so.", "Ok, I think so."),
    ])
    func inside(_ transcript: String, _ expected: String) async {
        #expect(await pasted(after: transcript) == [expected + " "])
    }

    @Test("a Filler that opens a sentence goes, and the next word takes the capital", arguments: [
        ("Ehm, volevo dire una cosa.", "Volevo dire una cosa."),
        ("Ok. Uhm, poi ci penso.", "Ok. Poi ci penso."),
        ("Mmh... sì, va bene.", "Sì, va bene."),
        ("Hmm, non so.", "Non so."),
    ])
    func sentenceStart(_ transcript: String, _ expected: String) async {
        #expect(await pasted(after: transcript) == [expected + " "])
    }

    @Test("words with meaning and words that contain a Filler stay", arguments: [
        "Cioè, tipo, volevo dire una cosa.",
        "Ehi, ciao!",
        "Ascolto Bach e Brahms.",
        "Sono 10 mm, umido e uh-oh no.",
    ])
    func untouched(_ transcript: String) async {
        #expect(await pasted(after: transcript) == [transcript + " "])
    }

    @Test("a Transcript made only of Fillers pastes nothing")
    func onlyFillers() async {
        #expect(await pasted(after: "Ehm... mmh.").isEmpty)
    }
}
