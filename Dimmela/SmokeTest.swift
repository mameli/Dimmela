#if DEBUG
import AVFoundation
import AppKit

/// Checks the speech model without a microphone or a keyboard, from the command line:
///
///     Dimmela.app/Contents/MacOS/Dimmela -transcribeFile <audio file>
///
/// Prints the Transcript, the time it took and the memory footprint, then quits.
@MainActor
enum SmokeTest {
    static func runIfRequested(model: SpeechModel) -> Bool {
        guard let path = UserDefaults.standard.string(forKey: "transcribeFile") else { return false }
        Task {
            do {
                var start = ContinuousClock.now
                try await model.prepare()
                print("model ready in \(ContinuousClock.now - start)")
                let samples = try read(URL(fileURLWithPath: path))
                start = ContinuousClock.now
                let text = try await model.transcribe(samples)
                print("transcribed \(samples.count / 16_000) s in \(ContinuousClock.now - start): \(text)")
                print(String(format: "footprint %.1f MB", footprintMB()))
            } catch {
                print("FAILED: \(error)")
            }
            NSApplication.shared.terminate(nil)
        }
        return true
    }

    private static func read(_ url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: input)
        let converter = AVAudioConverter(from: file.processingFormat, to: target)!
        let capacity = AVAudioFrameCount(Double(input.frameLength) * 16_000 / file.processingFormat.sampleRate) + 32
        let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity)!
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed { status.pointee = .endOfStream; return nil }
            consumed = true
            status.pointee = .haveData
            return input
        }
        if let error { throw error }
        return Array(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
    }

    private static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
}
#endif
