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

    /// Starts recording; `onLevel` gets the loudness (0...1) of each block of audio, on the audio thread.
    func start(onLevel: @escaping @Sendable (Float) -> Void = { _ in }) throws {
        guard Self.permission == .authorized else { throw Failure.permissionDenied }
        stopEngine()
        _ = samples.drain()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.noInput }
        // The channels are averaged here, then the converter only changes the sample rate: it cannot
        // mix down more than two channels, and the MacBook's built-in microphone has three.
        guard let mono = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: format.sampleRate, channels: 1, interleaved: false
        ), let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1, interleaved: false
        ), let converter = AVAudioConverter(from: mono, to: target) else { throw Failure.converter }

        input.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tapBlock(
            mono: mono, converter: converter, target: target, samples: samples, onLevel: onLevel
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
        mono: AVAudioFormat, converter: AVAudioConverter, target: AVAudioFormat, samples: SampleBuffer,
        onLevel: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            guard let input = mixDown(buffer, to: mono) else { return }
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
                return input
            }
            guard error == nil, let channel = output.floatChannelData?[0] else { return }
            let converted = UnsafeBufferPointer(start: channel, count: Int(output.frameLength))
            samples.append(converted)
            onLevel(level(of: converted))
        }
    }
}

/// The average of all the buffer's channels, as one channel at the same sample rate.
private func mixDown(_ buffer: AVAudioPCMBuffer, to mono: AVAudioFormat) -> AVAudioPCMBuffer? {
    let frames = Int(buffer.frameLength)
    let channels = Int(buffer.format.channelCount)
    guard let source = buffer.floatChannelData,
          let output = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buffer.frameLength),
          let destination = output.floatChannelData?[0]
    else { return nil }
    output.frameLength = buffer.frameLength
    let stride = buffer.format.isInterleaved ? channels : 1
    for frame in 0..<frames {
        var sum: Float = 0
        for channel in 0..<channels {
            sum += buffer.format.isInterleaved ? source[0][frame * stride + channel] : source[channel][frame]
        }
        destination[frame] = sum / Float(channels)
    }
    return output
}

/// RMS loudness mapped from -50 dB (silence) to -10 dB (loud speech) onto 0...1.
private func level(of samples: UnsafeBufferPointer<Float>) -> Float {
    guard !samples.isEmpty else { return 0 }
    let meanSquare = samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)
    let decibels = 10 * log10(max(meanSquare, 1e-10))
    return min(max((decibels + 50) / 40, 0), 1)
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
