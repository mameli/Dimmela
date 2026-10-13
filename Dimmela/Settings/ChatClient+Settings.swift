import DimmelaCore
import Foundation

extension ChatClient {
    /// Post-processing sits between the end of speech and the paste: give up rather than make
    /// the user wait; the Transcript is pasted instead.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        return URLSession(configuration: configuration)
    }()

    /// The client for the provider in Settings, with the key in the Keychain.
    static func configured() throws -> ChatClient {
        let provider = AppSettings.provider
        return ChatClient(
            baseURL: try provider.validatedBaseURL(), apiKey: Keychain.apiKey, model: provider.model
        ) { request in
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (data, http)
        }
    }
}
