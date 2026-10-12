@preconcurrency import AVFoundation
@preconcurrency import FluidAudio
import Foundation
import SwiftUI

// Throwaway spike for ticket 01: a menu-bar app shell that loads Parakeet TDT v3 through
// FluidAudio and reports its own memory footprint at each phase. Usage:
//   Spike <model-folder> <short.wav> <long.wav>

@main
struct SpikeApp: App {
    @NSApplicationDelegateAdaptor(Delegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Spike", systemImage: "waveform") {
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }
}

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        Task.detached { await runPhases() }
    }
}

func footprintMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
}

func report(_ phase: String, _ extra: String = "") {
    print(String(format: "PHASE %@ footprint=%.1fMB pid=%d %@", phase, footprintMB(), getpid(), extra))
    fflush(stdout)
}

func samples(_ path: String) throws -> [Float] {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
}

func ms(since start: ContinuousClock.Instant) -> Int {
    let d = ContinuousClock.now - start
    return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
}

func runPhases() async {
    let args = CommandLine.arguments
    let pause: Duration = .seconds(Int(ProcessInfo.processInfo.environment["SPIKE_PAUSE"] ?? "5")!)
    do {
        try await Task.sleep(for: pause)
        report("shell-idle")

        let short = try samples(args[2]), long = try samples(args[3])
        report("audio-loaded", "short=\(short.count) long=\(long.count)")

        var start = ContinuousClock.now
        let models = try await AsrModels.load(from: URL(fileURLWithPath: args[1]), version: .v3)
        let asr = AsrManager(config: .default, models: models)
        report("model-loaded", "load_ms=\(ms(since: start))")

        for (name, audio) in [("short", short), ("short", short), ("short", short), ("long", long)] {
            var state = TdtDecoderState.make()
            start = ContinuousClock.now
            let text = try await asr.transcribe(audio, decoderState: &state).text
            report("transcribed-\(name)", "ms=\(ms(since: start)) text=\"\(text)\"")
        }

        try await Task.sleep(for: pause)
        report("idle-loaded")
        try await Task.sleep(for: pause)  // window for an external `footprint` measurement

        await asr.cleanup()
        try await Task.sleep(for: pause)
        report("unloaded")
    } catch {
        print("ERROR \(error)")
    }
    exit(0)
}
