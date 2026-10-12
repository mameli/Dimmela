@preconcurrency import AVFoundation
import Foundation
import Synchronization
import os

private let logger = Logger(subsystem: "app.dimmela.Dimmela", category: "microphone")

/// Records the default microphone into memory as 16 kHz mono samples, the format Parakeet
/// takes. A new engine for every Dictation: a microphone plugged in or chosen between two
/// Dictations is simply the one the next engine finds. Voice processing stays off, so AirPods
/// do not switch to call mode.
///
/// Not tied to the main actor: the tap block runs on an audio thread.
final class MicrophoneRecorder: Sendable {
    enum Failure: Error, CustomStringConvertible {
        case permissionDenied
        case noInput
        case converter

        var description: String {
            switch self {
            case .permissionDenied: "Dimmela is not allowed to use the microphone (System Settings › Privacy & Security › Microphone)."
            case .noInput: "No microphone is available."
            case .converter: "The microphone's audio format is not supported."
            }
        }
    }

    static let sampleRate: Double = 16_000

    private let engine = Mutex<AVAudioEngine?>(nil)
    private let samples = SampleBuffer()

    static var permission: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    func start() throws {
        guard Self.permission == .authorized else { throw Failure.permissionDenied }
        stopEngine()
        _ = samples.drain()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.noInput }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false
        ), let converter = AVAudioConverter(from: format, to: target) else { throw Failure.converter }

        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tapBlock(
            converter: converter, target: target, samples: samples
        ))
        engine.prepare()
        try engine.start()
        self.engine.withLock { $0 = engine }
        logger.info("Recording from \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) channels")
    }

    /// Stops the microphone and returns everything recorded since `start()`.
    func stop() -> [Float] {
        stopEngine()
        return samples.drain()
    }

    private func stopEngine() {
        engine.withLock { engine in
            engine?.inputNode.removeTap(onBus: 0)
            engine?.stop()
            engine = nil
        }
    }

    /// Built outside any actor: the block is called on the audio thread.
    private static func tapBlock(
        converter: AVAudioConverter, target: AVAudioFormat, samples: SampleBuffer
    ) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 32
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            nonisolated(unsafe) var consumed = false
            var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, let channel = output.floatChannelData?[0] else { return }
            let converted = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
            samples.append(converted)
        }
    }
}

/// The samples recorded so far, written by the audio thread and taken by the caller.
private final class SampleBuffer: Sendable {
    private let storage = Mutex<[Float]>([])

    func append(_ samples: UnsafeBufferPointer<Float>) {
        storage.withLock { $0.append(contentsOf: samples) }
    }

    func drain() -> [Float] {
        storage.withLock { samples in
            defer { samples = [] }
            return samples
        }
    }
}
