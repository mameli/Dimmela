import DimmelaCore
import Foundation

private let logger = AppLog(category: "post-processing")

extension ChatClient {
    /// Post-processing sits between the end of speech and the paste: give up rather than make
    /// the user wait; the Transcript is pasted instead.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    enum ProfileFailure: LocalizedError {
        case none

        var errorDescription: String? {
            "No Provider profile: add one in Settings › Post-processing."
        }
    }

    /// The client for a Provider profile, the selected one by default, with its key from the
    /// Keychain.
    static func configured(_ profile: ProviderProfile? = AppSettings.selectedProviderProfile) throws -> ChatClient {
        guard let profile else { throw ProfileFailure.none }
        if let cli = profile.agentCLI {
            // What it logs holds no text: model, sizes, timing, usage, the agent's error.
            return AgentCLI.Runner(cli, log: { logger.info($0) }).client(for: profile)
        }
        let provider = profile.provider
        let keyStart = ContinuousClock.now
        let apiKey = Keychain.apiKey(for: profile.id)
        // Usually instant: slow when macOS asked the user to let this build read the key.
        if ContinuousClock.now - keyStart > .milliseconds(500) {
            logger.notice("Key read from the Keychain in \(AppModel.elapsed(since: keyStart))")
        }
        return ChatClient(
            baseURL: try provider.validatedBaseURL(), apiKey: apiKey, model: provider.model,
            reasoning: provider.reasoning, extraParameters: provider.extraParameters
        ) { request in
            // Every request with its timing, by where the provider runs: its address can name a company.
            let start = ContinuousClock.now
            let reasoning = provider.reasoning?.displayName ?? "model default"
            let summary = "\(provider.model) (\(provider.isOnThisMac ? "on this Mac" : "remote")), reasoning \(reasoning)"
                + (provider.extraParameters == nil ? "" : ", Extra parameters") + ", \(request.httpBody?.count ?? 0) bytes sent"
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
                logger.info("Post-processing \(summary): HTTP \(http.statusCode), \(data.count) bytes in \(AppModel.elapsed(since: start))")
                return (data, http)
            } catch {
                // By description only: a URLError's full form includes the address.
                logger.error("Post-processing \(summary): failed after \(AppModel.elapsed(since: start)): \(error.localizedDescription)")
                throw error
            }
        }
    }
}
