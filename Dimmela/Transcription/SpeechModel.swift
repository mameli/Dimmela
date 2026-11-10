@preconcurrency import FluidAudio
import Foundation
import Observation

private let logger = AppLog(category: "speech-model")

/// A speech model Dimmela offers, through FluidAudio. Both know the same 25 European languages.
enum SpeechModelChoice: String, CaseIterable, Identifiable, Sendable {
    /// NVIDIA Parakeet TDT v3: the only model up to 0.1.7, still the default.
    case v3 = "parakeet-tdt-0.6b-v3"
    /// Parakeet v3 trained further by moondream: same speed, fewer mistakes (FLEURS mean error
    /// 14.8% → 11.7%), sometimes an unrecognised word (`<unk>`, dropped).
    case ultra = "parakeet-ultra"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .v3: "Parakeet v3"
        case .ultra: "Parakeet Ultra"
        }
    }

    var downloadMB: Int {
        switch self {
        case .v3: 490
        case .ultra: 632
        }
    }

    var note: String {
        switch self {
        case .v3: "Very fast and accurate."
        case .ultra: "The most accurate, as fast as v3; a larger download."
        }
    }

    fileprivate var version: AsrModelVersion {
        switch self {
        case .v3: .v3
        case .ultra: .ultra
        }
    }

    /// FluidAudio downloads into a folder named after the model, under the one it is given.
    var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Dimmela/Models/fluidaudio/\(rawValue)", directoryHint: .isDirectory)
    }

    /// Written next to the model once it is fully downloaded: a download interrupted halfway is
    /// started again instead of being loaded.
    fileprivate static let downloadedMarker = ".dimmela-downloaded"

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: folder.appending(path: Self.downloadedMarker).path(percentEncoded: false))
    }

    /// The one chosen in Settings; v3 if none, or one no longer offered.
    static var selected: SpeechModelChoice {
        UserDefaults.standard.string(forKey: AppSettings.speechModelKey).flatMap(Self.init(rawValue:)) ?? .v3
    }
}

/// The chosen Parakeet model on the Neural Engine through FluidAudio: downloaded once, then kept
/// loaded for as long as Dimmela runs (ticket 01 measured 25–50 MB to keep v3 in memory).
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

    /// The model loaded, or being loaded.
    private(set) var choice = SpeechModelChoice.selected

    /// Downloads the model if needed and loads it. Later calls return at once.
    func prepare() async throws {
        _ = try await loaded()
    }

    /// Removes a model from this Mac; if it is the chosen one, the next Dictation, or `prepare()`,
    /// downloads it again.
    func delete(_ model: SpeechModelChoice? = nil) throws {
        let model = model ?? choice
        if model == choice {
            loading?.cancel()
            loading = nil
            asr = nil
            state = .notLoaded
        }
        try FileManager.default.removeItem(at: model.folder)
    }

    /// Switches to another model: the one loaded leaves memory (its files stay), the new one is
    /// downloaded if needed and loaded.
    func choose(_ model: SpeechModelChoice) {
        guard model != choice else { return }
        UserDefaults.standard.set(model.rawValue, forKey: AppSettings.speechModelKey)
        loading?.cancel()
        loading = nil
        asr = nil
        choice = model
        state = .notLoaded
        logger.info("Speech model: \(model.name)")
        Task { try? await prepare() }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        let asr = try await loaded()
        var decoderState = TdtDecoderState.make()
        return try await asr.transcribe(samples, decoderState: &decoderState).text
    }

    private func loaded() async throws -> AsrManager {
        if let asr { return asr }
        let model = choice
        let task = loading ?? Task { try await load(model) }
        loading = task
        do {
            let asr = try await task.value
            // Another model was chosen meanwhile: this one is not kept.
            guard model == choice else { return try await loaded() }
            self.asr = asr
            return asr
        } catch {
            guard model == choice else { return try await loaded() }
            loading = nil
            state = .failed(String(describing: error))
            throw error
        }
    }

    private func load(_ model: SpeechModelChoice) async throws -> AsrManager {
        let downloadedNow = !model.isDownloaded
        if downloadedNow {
            state = .downloading(0)
            // Whatever an interrupted download left is not trusted: start from scratch.
            try? FileManager.default.removeItem(at: model.folder)
            try FileManager.default.createDirectory(at: model.folder, withIntermediateDirectories: true)
            _ = try await AsrModels.download(to: model.folder, version: model.version) { progress in
                let percent = Int(progress.fractionCompleted * 100)
                Task { @MainActor in self.reportDownload(percent) }
            }
            try Task.checkCancellation()
            try Data().write(to: model.folder.appending(path: SpeechModelChoice.downloadedMarker))
            logger.info("Downloaded \(model.name)")
        }
        try Task.checkCancellation()
        state = .preparing(firstTime: downloadedNow)
        let start = ContinuousClock.now
        let models = try await AsrModels.load(from: model.folder, version: model.version)
        let asr = AsrManager(config: .default, models: models)
        logger.info("Loaded \(model.name) in \(ContinuousClock.now - start)")
        try Task.checkCancellation()
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
