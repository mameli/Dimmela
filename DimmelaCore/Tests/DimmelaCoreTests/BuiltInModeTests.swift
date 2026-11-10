import Foundation
import Testing
@testable import DimmelaCore

@Suite("Built-in Modes")
struct BuiltInModeTests {
    let folder = TemporaryFolder()

    private var modes: [Mode] { ModeCatalog.modes(in: [folder.url]) }

    private func text(_ name: String) throws -> String {
        try String(contentsOf: folder.url.appending(path: name), encoding: .utf8)
    }

    @Test("the first time, Clean and Markdown are written as prompt files, Modes like any other")
    func firstTime() throws {
        let written = try BuiltInModes.install(in: folder.url, firstTime: true)

        #expect(written.map(\.lastPathComponent) == ["clean.md", "markdown.md"])
        #expect(modes.map(\.name) == ["Clean", "Markdown"])
        let clean = try modes[0].instructions()
        let markdown = try modes[1].instructions()
        #expect(clean.contains("Resolve self-corrections"))
        #expect(!clean.contains("${output}"))
        #expect(markdown.contains("Resolve self-corrections"))
        #expect(markdown.contains("MARKDOWN FORMATTING"))
        #expect(markdown.contains("“- [ ] ”"))
        #expect(!markdown.contains("Do not apply Markdown formatting"))
    }

    @Test("a file the user edited is never replaced, not even the first time")
    func editedFileKept() throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try "Il mio prompt.".write(to: folder.url.appending(path: "clean.md"), atomically: true, encoding: .utf8)

        try BuiltInModes.install(in: folder.url, firstTime: true)
        try BuiltInModes.install(in: folder.url, firstTime: false, earlierVersions: ["clean.md": [BuiltInModes.version(of: "Old.")]])

        #expect(try text("clean.md") == "Il mio prompt.")
        #expect(try text("markdown.md") == BuiltInModes.markdown)
    }

    @Test("a file still holding an earlier text of Dimmela's gets the current one")
    func unchangedFileUpdated() throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        try "Old prompt.".write(to: folder.url.appending(path: "markdown.md"), atomically: true, encoding: .utf8)

        let written = try BuiltInModes.install(
            in: folder.url, firstTime: false, earlierVersions: ["markdown.md": [BuiltInModes.version(of: "Old prompt.")]]
        )

        #expect(written.map(\.lastPathComponent) == ["markdown.md"])
        #expect(try text("markdown.md") == BuiltInModes.markdown)
    }

    @Test("a file the user deleted stays deleted")
    func deletedFileStaysDeleted() throws {
        try BuiltInModes.install(in: folder.url, firstTime: true)
        try FileManager.default.removeItem(at: folder.url.appending(path: "markdown.md"))

        let written = try BuiltInModes.install(in: folder.url, firstTime: false)

        #expect(written.isEmpty)
        #expect(modes.map(\.name) == ["Clean"])
    }

    @Test("the shipped texts are not listed as earlier versions: they would be replaced by themselves")
    func currentIsNotEarlier() {
        for file in BuiltInModes.files {
            #expect(BuiltInModes.earlierVersions[file.name]?.contains(BuiltInModes.version(of: file.text)) != true)
        }
    }
}
