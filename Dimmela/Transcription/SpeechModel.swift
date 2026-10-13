@preconcurrency import FluidAudio
import Foundation
import Observation
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "speech-model")

/// Parakeet TDT v3 on the Neural Engine through FluidAudio: downloaded once, then kept loaded
/// for as long as Dimmela runs (ticket 01 measured 25–50 MB to keep it in memory).
@MainActor
@Observable
final class SpeechModel {
    enum State: Equatable {
        case notLoaded
        /// Whole percent of the download.
        case downloading(Int)
        /// Loading; the first time after a download macOS also compiles it for the Neural Engine.
        case preparing(firstTime: Bool)
        case ready
        case failed(String)
    }

    private(set) var state: State = .notLoaded

    @ObservationIgnored private var asr: AsrManager?
    @ObservationIgnored private var loading: Task<AsrManager, Error>?

    static var folder: URL {
        URL.applicationSupportDirectory.appending(
            path: "Dimmela/Models/fluidaudio/parakeet-tdt-0.6b-v3", directoryHint: .isDirectory
        )
    }

    /// Written next to the model once it is fully downloaded: a download interrupted halfway is
    /// started again instead of being loaded.
    private static let downloadedMarker = ".dimmela-downloaded"

    static let downloadMB = 490

    static var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: downloadedMarker).path(percentEncoded: false))
    }

    /// Downloads the model if needed and loads it. Later calls return at once.
    func prepare() async throws {
        _ = try await loaded()
    }

    /// Removes the model from this Mac; the next Dictation, or `prepare()`, downloads it again.
    func delete() throws {
        loading?.cancel()
        loading = nil
        asr = nil
        try FileManager.default.removeItem(at: Self.folder)
        state = .notLoaded
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        let asr = try await loaded()
        var decoderState = TdtDecoderState.make()
        return try await asr.transcribe(samples, decoderState: &decoderState).text
    }

    private func loaded() async throws -> AsrManager {
        if let asr { return asr }
        let task = loading ?? Task { try await load() }
        loading = task
        do {
            let asr = try await task.value
            self.asr = asr
            return asr
        } catch {
            loading = nil
            state = .failed(String(describing: error))
            throw error
        }
    }

    private func load() async throws -> AsrManager {
        let downloadedNow = !Self.isDownloaded
        if downloadedNow {
            state = .downloading(0)
            // Whatever an interrupted download left is not trusted: start from scratch.
            try? FileManager.default.removeItem(at: Self.folder)
            try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
            _ = try await AsrModels.download(to: Self.folder, version: .v3) { progress in
                let percent = Int(progress.fractionCompleted * 100)
                Task { @MainActor in self.reportDownload(percent) }
            }
            try Data().write(to: Self.folder.appending(path: Self.downloadedMarker))
            logger.info("Downloaded Parakeet v3")
        }
        state = .preparing(firstTime: downloadedNow)
        let start = ContinuousClock.now
        let models = try await AsrModels.load(from: Self.folder, version: .v3)
        let asr = AsrManager(config: .default, models: models)
        logger.info("Loaded Parakeet v3 in \(ContinuousClock.now - start, privacy: .public)")
        state = .ready
        return asr
    }

    /// Whole percents only, and never backwards: reports arrive many times a second and not
    /// always in order.
    private func reportDownload(_ percent: Int) {
        guard case .downloading(let current) = state, percent > current else { return }
        state = .downloading(percent)
    }
}
