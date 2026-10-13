import Foundation

/// What *Report a Problem…* says about Dimmela and the Mac: filled in the GitHub bug form
/// (`.github/ISSUE_TEMPLATE/bug_report.yml`, fields by id) and written at the top of the report
/// file, above the logs. In English, like the issues. Nothing that names the user, their
/// Dictations or the provider's address (from Takku).
public struct ProblemReport: Equatable, Sendable {
    public var version: String
    public var system: String
    /// One of the form's "Installed with" options, or `nil` to let the user choose.
    public var installedWith: String?
    public var postProcessing: String

    public init(version: String, system: String, installedWith: String?, postProcessing: String) {
        self.version = version
        self.system = system
        self.installedWith = installedWith
        self.postProcessing = postProcessing
    }

    /// The provider by model and where it runs: its address can name a company.
    public static func postProcessing(provider: Provider, isUsed: Bool) -> String {
        guard isUsed else { return "Not used" }
        let host = URL(string: provider.baseURL.trimmingCharacters(in: .whitespaces))?.host()?.lowercased() ?? ""
        let onThisMac = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
        return "\(provider.model) (\(onThisMac ? "on this Mac" : "remote"))"
    }

    public var issueURL: URL {
        var components = URLComponents(string: "https://github.com/mameli/Dimmela/issues/new")!
        let fields: [(String, String?)] = [
            ("template", "bug_report.yml"), ("version", version), ("macos", system),
            ("install", installedWith), ("postprocessing", postProcessing),
        ]
        components.queryItems = fields.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
        return components.url!
    }

    public func text(logs: String) -> String {
        """
        Dimmela problem report
        Check this file before attaching it to a public issue, and remove anything you don't want to share.

        Dimmela: \(version)
        System: \(system)
        Installed with: \(installedWith ?? "unknown")
        Post-processing: \(postProcessing)

        Logs:
        \(logs)

        """
    }
}
