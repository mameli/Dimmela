import DimmelaCore
import Foundation
import os

/// Logs to the system log and to `~/Library/Logs/Dimmela/Dimmela.log`, which also keeps the
/// info messages and is opened by Console. Messages are public: they must never hold the
/// Transcript, the text, the provider's address, the key or the Extra parameters.
struct AppLog: Sendable {
    static let file = LogFile(url: URL.libraryDirectory.appending(path: "Logs/Dimmela/Dimmela.log"))

    private static let timestamp = Date.ISO8601FormatStyle(dateTimeSeparator: .space, timeZone: .current)
        .year().month().day().time(includingFractionalSeconds: true)

    private let category: String
    private let logger: Logger

    init(category: String) {
        self.category = category
        logger = Logger(subsystem: "app.dimmela.Dimmela", category: category)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        write("I", message)
    }

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        write("N", message)
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        write("E", message)
    }

    private func write(_ level: String, _ message: String) {
        Self.file.write("\(Date.now.formatted(Self.timestamp)) \(level) [\(category)] \(message)")
    }
}
