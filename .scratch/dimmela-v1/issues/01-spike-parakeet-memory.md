# 01: Spike: Parakeet memory with FluidAudio

**What to build:** A throwaway minimal macOS app that downloads and loads Parakeet TDT v3 through FluidAudio, transcribes a bundled Italian audio file, and lets us measure the memory footprint (`footprint`) at rest with the model unloaded and loaded, plus transcription latency. The outcome is a short note next to this ticket with the numbers and a go/no-go against the targets (under 60 MB without the model, under 450 MB with it; Handy baseline 922 MB). See ADR 0001.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [x] Parakeet TDT v3 is downloaded and loaded via FluidAudio on the Neural Engine
- [x] A bundled Italian audio sample is transcribed and the Transcript is printed
- [x] Footprint is measured idle without the model, idle with the model loaded, and right after a transcription
- [x] Latency of a ~10 s and a ~60 s transcription is recorded, plus first-load (ANE compile) time
- [x] A note with the numbers and a go/no-go decision is appended to this ticket under `## Comments`
- [x] The spike code is not carried into the real project

## Comments

### Results (2026-10-12, M3 Pro 18 GB, macOS 26, FluidAudio 0.17.5, Parakeet TDT v3 int8)

Spike code: `.scratch/dimmela-v1/spike-01/` (SwiftUI `MenuBarExtra` shell, SPM executable). Regenerate the audio with `say -v Alice -f audio/<name>.txt -o audio/<name>.wav --data-format=LEI16@16000` (Italian TTS: 6.7 s and 55.6 s). Run with `.build/release/Spike <model-folder> audio/short.wav audio/long.wav`. Memory is the process `phys_footprint`, the same figure `footprint` and Activity Monitor report, read by the app and cross-checked with `footprint`.

| Phase | Footprint |
|---|---|
| App shell idle, no model | 13.7 MB |
| Model loaded | 38–39 MB |
| After transcriptions, idle with the model loaded | 65–67 MB (external `footprint`: 67 MB) |
| After `AsrManager.cleanup()` | 39–59 MB |
| Handy 0.9.7 with Parakeet loaded (baseline) | 922 MB |

| Timing | Value |
|---|---|
| First model load, new binary (Neural Engine compile) | 16.7 s |
| Later loads (warm cache) | 0.2 s |
| Transcribe 6.7 s of audio | 63–85 ms |
| Transcribe 55.6 s of audio | 224 ms |

**Caveat: the weights live outside the process.** On the Neural Engine, the model weights are file-mapped from the `.mlmodelc` (284 MB virtual, about 37 MB resident) and held in kernel-wired ANE buffers, so they are not counted in the process footprint. The machine was under memory pressure (about 60 MB free, a 6.5 GB compressor), so the system-wide wired delta was noisy: +40 to +230 MB with the model loaded, and it did not drop after `cleanup()`. Even the worst-case sum is well under the 450 MB target.

**Recognition quality.** TTS audio is not representative of real speech, but the errors already show the Vocabulary is needed: "Jira" became "IRA", "X su Claude" became "XUCload", "Parakeet" became "Parachaet", "OpenRouter" became "OPIR router", and "Handy" became "Andy". Numbers come out as digits ("alle 10").

**API note.** In FluidAudio 0.17.5, `AsrManager.transcribe` takes an optional `language:` hint for v3. It only filters tokens by script (Latin vs Cyrillic and so on), so it cannot tell Italian from English.

### Decision: GO

- **Memory.** Both targets are met with a wide margin: under 60 MB without the model and under 450 MB with it loaded.
- **Model unloading (ticket 13).** Keeping Parakeet loaded costs about 25–50 MB of process footprint, and a warm reload takes 0.2 s. The unload-after-inactivity option therefore buys almost nothing. Proposal: drop it from ticket 13 and keep the model always loaded.
- **First load.** The one-time Neural Engine compile (about 17 s here; Takku saw minutes on first download) belongs in onboarding (ticket 12), as planned.
