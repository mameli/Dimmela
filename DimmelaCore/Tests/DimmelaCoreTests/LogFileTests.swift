import DimmelaCore
import Foundation
import Testing

@Suite("Log file")
struct LogFileTests {
    let folder = TemporaryFolder()

    @Test("lines are appended in order, and the folder is created")
    func append() {
        let log = LogFile(url: folder.url.appending(path: "Logs/Dimmela.log"))
        log.write("one")
        log.write("two")
        #expect(log.contents == "one\ntwo\n")
    }

    @Test("past the limit the file becomes the previous one: the two never exceed twice the limit")
    func rotation() throws {
        let log = LogFile(url: folder.url.appending(path: "Dimmela.log"), maxBytes: 100)
        for index in 0..<50 { log.write("line \(String(format: "%02d", index))") }

        let files = try FileManager.default.contentsOfDirectory(atPath: folder.url.path(percentEncoded: false)).sorted()
        #expect(files == ["Dimmela.1.log", "Dimmela.log"])
        let sizes = try files.map { try FileManager.default.attributesOfItem(atPath: folder.url.appending(path: $0).path)[.size] as! Int }
        #expect(sizes.allSatisfy { $0 <= 100 })
        // The newest lines are kept, oldest first; the first ones are gone.
        #expect(log.contents.hasSuffix("line 48\nline 49\n"))
        #expect(!log.contents.contains("line 00"))
        let lines = log.contents.split(separator: "\n")
        #expect(lines == lines.sorted())
    }
}
