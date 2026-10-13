@preconcurrency import FluidAudio
import Foundation
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "speech-detector")

/// Silero voice activity detection through FluidAudio: where a Dictation's speech starts and
/// ends. Its small model is downloaded once, next to Parakeet.
@MainActor
final class SpeechDetector {
    enum Failure: Error {
        case notLoaded
    }

    /// Silero's usual threshold. FluidAudio's default (0.85) misses speech said quietly, and a
    /// Dictation judged silent is lost.
    private static let threshold: Float = 0.5

    private var vad: VadManager?

    func prepare() async {
        guard vad == nil else { return }
        do {
            vad = try await VadManager(
                config: VadConfig(defaultThreshold: Self.threshold),
                modelDirectory: URL.applicationSupportDirectory.appending(path: "Dimmela", directoryHint: .isDirectory)
            )
        } catch {
            logger.error("Voice activity detection unavailable: \(error, privacy: .public)")
        }
    }

    /// From the start of the first speech segment to the end of the last (padded by FluidAudio);
    /// nil if there is no speech. Throws while the model is not loaded.
    func speechRange(in samples: [Float]) async throws -> Range<Int>? {
        guard let vad else { throw Failure.notLoaded }
        let segments = try await vad.segmentSpeech(samples)
        guard let first = segments.first, let last = segments.last else { return nil }
        let start = first.startSample(sampleRate: VadManager.sampleRate)
        let end = min(last.endSample(sampleRate: VadManager.sampleRate), samples.count)
        return start < end ? start..<end : nil
    }
}
