import Foundation

/// The OpenAI-compatible server Post-processing calls. The API key is not stored here: it
/// lives in the Keychain.
public struct Provider: Equatable, Sendable {
    public static let openRouter = Provider(baseURL: "https://openrouter.ai/api/v1", model: "anthropic/claude-haiku-5.5")

    public var baseURL: String
    public var model: String

    public init(baseURL: String, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    public enum Failure: LocalizedError, Equatable {
        case invalidURL(String)
        case insecureURL(String)
        case noModel

        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url): "Invalid provider URL: \"\(url)\" (http:// or https:// and an address are needed)."
            case .insecureURL(let url): "Plain-text provider URL: \"\(url)\". Use https://; http:// is allowed only for servers on this Mac."
            case .noModel: "No model is set for the provider."
            }
        }
    }

    /// Plain HTTP only towards this Mac: to any other machine, even on the local network, the
    /// key and the Transcript would travel readable.
    private static let loopbackHosts: Set<String> = ["localhost", "127.0.0.1", "::1", "[::1]"]

    /// The base URL to call, if the provider is usable.
    public func validatedBaseURL() throws -> URL {
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), !host.isEmpty
        else { throw Failure.invalidURL(baseURL) }
        guard scheme == "https" || Self.loopbackHosts.contains(host.lowercased()) else {
            throw Failure.insecureURL(baseURL)
        }
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else { throw Failure.noModel }
        return url
    }
}
