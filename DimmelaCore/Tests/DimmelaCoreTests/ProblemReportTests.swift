import DimmelaCore
import Foundation
import Testing

@Suite("Report a problem")
struct ProblemReportTests {
    let report = ProblemReport(
        version: "0.1.0 (1)", system: "macOS 26.0.1, Mac15,6, 18 GB", installedWith: "Homebrew",
        postProcessing: "anthropic/claude-haiku-5.5 (remote)"
    )

    func query(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test("the issue link opens the bug form with the fields filled in")
    func issueURL() {
        let url = report.issueURL
        #expect(url.absoluteString.hasPrefix("https://github.com/mameli/Dimmela/issues/new?"))
        #expect(query(url) == [
            "template": "bug_report.yml", "version": "0.1.0 (1)", "macos": "macOS 26.0.1, Mac15,6, 18 GB",
            "install": "Homebrew", "postprocessing": "anthropic/claude-haiku-5.5 (remote)",
        ])
        #expect(!url.absoluteString.contains(" "))
    }

    @Test("an unknown install method is left for the user to choose")
    func unknownInstall() {
        var report = report
        report.installedWith = nil
        #expect(query(report.issueURL)["install"] == nil)
    }

    @Test("the file lists the same fields, a warning to check it, then the logs")
    func text() {
        let text = report.text(logs: "2026-10-13 E Dimmela[1] failed")
        #expect(text.contains("Check this file before attaching it"))
        #expect(text.contains("Dimmela: 0.1.0 (1)"))
        #expect(text.contains("Installed with: Homebrew"))
        #expect(text.contains("Post-processing: anthropic/claude-haiku-5.5 (remote)"))
        #expect(text.hasSuffix("2026-10-13 E Dimmela[1] failed\n"))
    }

    @Test("Post-processing is described by model and where it runs, never by address")
    func postProcessing() {
        let local = Provider(baseURL: "http://localhost:1234/v1", model: "qwen")
        let remote = Provider(baseURL: "https://llm.acme.internal/v1", model: "gpt")
        #expect(ProblemReport.postProcessing(provider: local, isUsed: false) == "Not used")
        #expect(ProblemReport.postProcessing(provider: local, isUsed: true) == "qwen (on this Mac)")
        #expect(ProblemReport.postProcessing(provider: remote, isUsed: true) == "gpt (remote)")
    }
}
