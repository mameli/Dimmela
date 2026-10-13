import Foundation
import Observation

/// A Dictation kept in the History.
public struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let date: Date
    public let transcript: String
    /// What was pasted: the LLM's answer, or the Transcript when there was no Post-processing.
    public let text: String
    public let modeID: String?
    /// The Mode's name when it was used, also shown after its files are gone.
    public let modeName: String?

    public var mode: Mode? { modeID.map(Mode.init(id:)) }
}

/// The last Dictations, newest first, each in its own folder with its audio: copied or
/// Post-processed again from the menu. Older ones are deleted as new ones arrive.
@MainActor
@Observable
public final class History {
    public static let limit = 5

    public private(set) var entries: [HistoryEntry] = []

    @ObservationIgnored private let directory: URL
    private static let entryFile = "entry.json"
    private static let audioFile = "audio.wav"

    public init(directory: URL) {
        self.directory = directory
        entries = Self.load(from: directory)
    }

    public func audioURL(of entry: HistoryEntry) -> URL {
        folder(of: entry).appending(path: Self.audioFile)
    }

    /// Keeps a Dictation and deletes what falls beyond the limit.
    public func add(transcript: String, text: String, mode: Mode?, samples: [Float], date: Date = .now) throws {
        let entry = HistoryEntry(
            id: UUID(), date: date, transcript: transcript, text: text, modeID: mode?.id, modeName: mode?.name
        )
        let folder = folder(of: entry)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Self.wav(samples).write(to: folder.appending(path: Self.audioFile))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entry).write(to: folder.appending(path: Self.entryFile))

        entries.insert(entry, at: 0)
        for old in entries.dropFirst(Self.limit) {
            try? FileManager.default.removeItem(at: self.folder(of: old))
        }
        entries = Array(entries.prefix(Self.limit))
    }

    private func folder(of entry: HistoryEntry) -> URL {
        directory.appending(path: entry.id.uuidString, directoryHint: .isDirectory)
    }

    private static func load(from directory: URL) -> [HistoryEntry] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders
            .compactMap { folder in
                guard let data = try? Data(contentsOf: folder.appending(path: entryFile)) else { return nil }
                return try? JSONDecoder().decode(HistoryEntry.self, from: data)
            }
            .sorted { $0.date > $1.date }
    }

    /// 16 kHz mono, 16-bit PCM: any player opens it, and it is half the size of the floats.
    private static func wav(_ samples: [Float]) -> Data {
        let sampleRate: UInt32 = 16_000
        let dataSize = UInt32(samples.count * 2)
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + dataSize)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))  // PCM
        append(UInt16(1))  // mono
        append(sampleRate)
        append(sampleRate * 2)  // bytes per second
        append(UInt16(2))  // bytes per frame
        append(UInt16(16))  // bits per sample
        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        for sample in samples {
            append(Int16((min(max(sample, -1), 1) * Float(Int16.max)).rounded()))
        }
        return data
    }
}
