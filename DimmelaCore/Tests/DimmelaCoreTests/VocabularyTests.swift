import DimmelaCore
import Foundation
import Testing

@Suite("Vocabulary entries")
struct VocabularyEntryTests {
    @Test("an entry gives the term, its variants and its description")
    func fullEntry() {
        let vocabulary = Vocabulary(text: "- Jira = gira, ira | the issue tracker at work")
        #expect(vocabulary.entries == [
            Vocabulary.Entry(term: "Jira", variants: ["gira", "ira"], description: "the issue tracker at work"),
        ])
    }

    @Test("an entry can be just the term; lines that are not list items are ignored")
    func termOnlyAndFreeText() {
        let vocabulary = Vocabulary(text: """
            My words:
            - Claude
            Not an entry = ignored
            - OpenRouter = open router
            """)
        #expect(vocabulary.entries.map(\.term) == ["Claude", "OpenRouter"])
    }

    @Test("the same term or variant twice: the first counts; degenerate pieces are dropped")
    func duplicates() {
        let vocabulary = Vocabulary(text: """
            - Jira = gira
            - Claude = cloud, gira,, ,Claude
            - jira = ira
            -
            - = orphan
            """)
        #expect(vocabulary.entries == [
            Vocabulary.Entry(term: "Jira", variants: ["gira"]),
            Vocabulary.Entry(term: "Claude", variants: ["cloud"]),
        ])
    }

    @Test("the preview names the first terms read, then how many more")
    func preview() {
        #expect(Vocabulary(text: "").preview == nil)
        #expect(Vocabulary(text: "- Jira").preview == "Jira")
        #expect(Vocabulary(text: "- Jira\n- Claude").preview == "Jira and Claude")
        #expect(Vocabulary(text: "- Jira\n- Claude\n- OpenRouter").preview == "Jira, Claude and OpenRouter")
        let six = (1...6).map { "- Term\($0)" }.joined(separator: "\n")
        #expect(Vocabulary(text: six).preview == "Term1, Term2, Term3, Term4 and 2 more")
        let five = (1...5).map { "- Term\($0)" }.joined(separator: "\n")
        #expect(Vocabulary(text: five).preview == "Term1, Term2, Term3, Term4 and 1 more")
    }

    @Test("the new Vocabulary file explains the syntax but adds no entries")
    func fileTemplate() {
        #expect(Vocabulary.fileTemplate.hasPrefix("# Vocabulary\n"))
        #expect(Vocabulary.fileTemplate.contains(Vocabulary.example))
        #expect(Vocabulary(text: Vocabulary.fileTemplate).entries.isEmpty)
        #expect(Vocabulary(text: Vocabulary.fileTemplate + "- Jira = ira\n").entries.map(\.term) == ["Jira"])
    }

    @Test("the example explains the syntax but adds no entries")
    func example() {
        #expect(Vocabulary.example.contains("`- Jira = gira, ira | the issue tracker at work`"))
        #expect(Vocabulary(text: Vocabulary.example).entries.isEmpty)
    }
}

@MainActor
@Suite("Vocabulary in Dictations")
struct VocabularyDictationTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    private func dictate(_ transcript: String) async -> DictationController {
        fake.transcript = .success(transcript)
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        return controller
    }

    @Test("known variants become the term, whatever their case, whole words only")
    func substitution() async {
        fake.vocabulary = Vocabulary(text: "- Jira = ira, gira\n- OpenRouter = opir router, open router")
        _ = await dictate("Apro IRA su OPIR router, ma la Lira e girare restano.")
        #expect(fake.pasted == ["Apro Jira su OpenRouter, ma la Lira e girare restano. "])
    }

    @Test("the longest variant wins")
    func longest() async {
        fake.vocabulary = Vocabulary(text: "- Claude Code = cloud code\n- Claude = cloud")
        _ = await dictate("Uso cloud code e cloud.")
        #expect(fake.pasted == ["Uso Claude Code e Claude. "])
    }

    @Test("the History keeps the corrected Transcript")
    func history() async throws {
        fake.vocabulary = Vocabulary(text: "- Jira = ira")
        _ = await dictate("Apro ira.")
        #expect(try #require(fake.history.entries.first).transcript == "Apro Jira.")
    }

    @Test("Post-processing gets the Transcript corrected and the Vocabulary after the Mode's instructions")
    func promptBlock() async {
        fake.vocabulary = Vocabulary(text: "- Jira = ira | the issue tracker\n- Claude")
        fake.defaultMode = Mode(id: folder.write("clean.md", "Clean up.").path(percentEncoded: false))
        _ = await dictate("Apro ira con cloud.")

        #expect(fake.provider.message(0, "user") == "Apro Jira con cloud.")
        #expect(fake.provider.message(0, "system") == """
            Clean up.

            Vocabulary, names and technical terms the speaker uses:
            - Jira: the issue tracker (may be written as "ira")
            - Claude
            The Transcript comes from automatic speech recognition and may spell them wrong. \
            Use the Vocabulary and the context to write them right, but correct a word only when you are sure; \
            otherwise leave it as it is.
            """)
    }

    @Test("a skill gets the Vocabulary too")
    func skill() async {
        fake.vocabulary = Vocabulary(text: "- Claude")
        folder.write("editor/SKILL.md", "---\nname: editor\n---\nProofread.")
        fake.defaultMode = Mode(id: folder.url.appending(path: "editor").path(percentEncoded: false))
        _ = await dictate("Ciao.")
        #expect(fake.provider.message(0, "system")?.hasSuffix("otherwise leave it as it is.") == true)
        #expect(fake.provider.message(0, "system")?.contains("Proofread.\n\nVocabulary,") == true)
    }

    @Test("with an empty Vocabulary the Mode's instructions are sent alone")
    func empty() async {
        fake.defaultMode = Mode(id: folder.write("clean.md", "Clean up.").path(percentEncoded: false))
        _ = await dictate("Ciao.")
        #expect(fake.provider.message(0, "system") == "Clean up.")
    }
}
