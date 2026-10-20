import Foundation
import Synchronization

/// Lines appended to a file, for Dimmela's own log and the Post-processing log. Past `maxBytes`
/// the file becomes the previous one (`Dimmela.1.log`) and a new one starts, so the two never
/// take more than twice `maxBytes`.
public final class LogFile: Sendable {
    public let url: URL
    private let previousURL: URL
    private let maxBytes: Int
    private let lock = Mutex(())

    public init(url: URL, maxBytes: Int = 512 * 1024) {
        self.url = url
        previousURL = url.deletingPathExtension().appendingPathExtension("1").appendingPathExtension(url.pathExtension)
        self.maxBytes = maxBytes
    }

    public func write(_ line: String) {
        let data = Data((line + "\n").utf8)
        lock.withLock { _ in
            let files = FileManager.default
            let size = (try? files.attributesOfItem(atPath: url.path(percentEncoded: false))[.size] as? Int) ?? 0
            if size > 0, size + data.count > maxBytes {
                try? files.removeItem(at: previousURL)
                try? files.moveItem(at: url, to: previousURL)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: url)
            }
        }
    }

    /// Both files, oldest line first.
    public var contents: String {
        lock.withLock { _ in
            [previousURL, url].compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
        }
    }
}
