import DimmelaCore
import Foundation
import Testing

@MainActor
@Suite("Skills as Modes")
struct SkillModeTests {
    let fake = FakeBoundaries()
    let folder = TemporaryFolder()

    private func dictate(with mode: URL) async -> DictationController {
        fake.defaultMode = Mode(id: mode.path(percentEncoded: false))
        let controller = fake.controllerWired()
        await controller.shortcutDown(at: 10)
        await controller.shortcutUp(at: 11)
        return controller
    }

    @Test("a skill is sent as the preamble, then SKILL.md without frontmatter, then its references in order")
    func fullSkill() async {
        folder.write("stop-slop/SKILL.md", "---\nname: stop-slop\ndescription: Cut AI tells.\n---\n\n# Stop Slop\n\nSee references/phrases.md.\n")
        folder.write("stop-slop/references/phrases.md", "Avoid \"delve\".")
        folder.write("stop-slop/references/examples.md", "Before / after.")
        folder.write("stop-slop/README.md", "Not for the model.")
        folder.write("stop-slop/scripts/check.sh", "echo no")
        folder.write("stop-slop/references/data.json", "{}")

        _ = await dictate(with: folder.url.appending(path: "stop-slop"))

        #expect(fake.provider.message(0, "system") == """
        \(Mode.skillPreamble)

        # Stop Slop

        See references/phrases.md.

        # File: references/examples.md

        Before / after.

        # File: references/phrases.md

        Avoid "delve".
        """)
        #expect(fake.provider.message(0, "user") == "Ciao, sto provando Dimmela.")
        #expect(fake.pasted == ["Testo rifinito. "])
    }

    @Test("a skill with no references is the preamble and its body")
    func bareSkill() async {
        folder.write("editor/SKILL.md", "---\nname: editor\n---\nProofread.")
        _ = await dictate(with: folder.url.appending(path: "editor"))
        #expect(fake.provider.message(0, "system") == "\(Mode.skillPreamble)\n\nProofread.")
    }

    @Test("a skill whose folder is gone pastes the Transcript and reports the problem")
    func goneSkill() async {
        _ = await dictate(with: folder.url.appending(path: "gone"))
        #expect(fake.provider.requests.isEmpty)
        #expect(fake.pasted == ["Ciao, sto provando Dimmela. "])
        #expect(fake.problems.count == 1)
    }
}
