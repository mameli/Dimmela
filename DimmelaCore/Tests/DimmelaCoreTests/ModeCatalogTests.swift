import DimmelaCore
import Foundation
import Testing

@Suite("Mode catalog")
struct ModeCatalogTests {
    let folder = TemporaryFolder()

    @Test("every Markdown file at the top of a Mode source is a prompt-file Mode, by name")
    func promptFiles() {
        folder.write("translate-to-english.md", "Translate.")
        folder.write("prompt.md", "Clean up.")
        folder.write("compose_x_post.md", "Compose.")

        let modes = ModeCatalog.modes(in: [folder.url])
        #expect(modes.map(\.name) == ["Compose x post", "Prompt", "Translate to english"])
    }

    @Test("READMEs, other files and nested files are not Modes")
    func ignored() {
        folder.write("README.md", "# About")
        folder.write("readme.md", "# About")
        folder.write("notes.txt", "Not a prompt.")
        folder.write("assets/prompt.md", "Nested.")
        folder.write("prompt.md", "Clean up.")

        #expect(ModeCatalog.modes(in: [folder.url]).map(\.name) == ["Prompt"])
    }

    @Test("Modes from several sources are listed source by source; a missing source has none")
    func severalSources() {
        let other = TemporaryFolder()
        other.write("b.md", "B")
        folder.write("a.md", "A")
        let missing = folder.url.appending(path: "gone")

        let modes = ModeCatalog.modes(in: [folder.url, missing, other.url])
        #expect(modes.map(\.name) == ["A", "B"])
    }

    @Test("a Mode is identified by its file, so it is found again after a relaunch")
    func identity() {
        let file = folder.write("prompt.md", "Clean up.")
        let found = ModeCatalog.modes(in: [folder.url])[0]
        #expect(found == Mode(id: file.path(percentEncoded: false)))
        #expect(found.name == "Prompt")
    }

    @Test("a folder with a SKILL.md is a skill Mode, named after its frontmatter")
    func skills() {
        folder.write("mameli-x-voice/SKILL.md", "---\nname: mameli-x-voice\ndescription: X posts.\n---\n\n# Voice\n")
        folder.write("untitled-skill/SKILL.md", "# No frontmatter\n")
        folder.write("not-a-skill/notes.md", "Just notes.")

        let modes = ModeCatalog.modes(in: [folder.url])
        #expect(modes.map(\.name) == ["Mameli x voice", "Untitled skill"])
        #expect(modes[0].id == folder.url.appending(path: "mameli-x-voice").path(percentEncoded: false))
    }

    @Test("skills and prompt files of a source are sorted together")
    func mixed() {
        folder.write("b-skill/SKILL.md", "---\nname: b-skill\n---\nB")
        folder.write("a-prompt.md", "A")
        folder.write("c-prompt.md", "C")
        #expect(ModeCatalog.modes(in: [folder.url]).map(\.name) == ["A prompt", "B skill", "C prompt"])
    }

    @Test("skills reached through symbolic links are found")
    func symlinks() throws {
        let real = TemporaryFolder()
        real.write("stop-slop/SKILL.md", "---\nname: stop-slop\n---\nCut the slop.")
        real.write("prompt.md", "Clean up.")
        try FileManager.default.createSymbolicLink(
            at: folder.url.appending(path: "stop-slop"), withDestinationURL: real.url.appending(path: "stop-slop")
        )
        try FileManager.default.createSymbolicLink(
            at: folder.url.appending(path: "prompt.md"), withDestinationURL: real.url.appending(path: "prompt.md")
        )
        #expect(ModeCatalog.modes(in: [folder.url]).map(\.name) == ["Prompt", "Stop slop"])
    }

    @Test("a Mode whose files are gone is reported missing")
    func missing() {
        let skill = folder.url.appending(path: "gone-skill").path(percentEncoded: false)
        let prompt = folder.write("prompt.md", "Clean up.").path(percentEncoded: false)
        #expect(Mode(id: skill).isMissing)
        #expect(!Mode(id: prompt).isMissing)
    }
}
