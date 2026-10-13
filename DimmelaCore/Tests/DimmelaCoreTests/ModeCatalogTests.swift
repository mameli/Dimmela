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
}
