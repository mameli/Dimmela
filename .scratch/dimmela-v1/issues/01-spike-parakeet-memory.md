# 01: Spike: Parakeet memory with FluidAudio

**What to build:** A throwaway minimal macOS app that downloads and loads Parakeet TDT v3 through FluidAudio, transcribes a bundled Italian audio file, and lets us measure the memory footprint (`footprint`) at rest with the model unloaded and loaded, plus transcription latency. The outcome is a short note next to this ticket with the numbers and a go/no-go against the targets (under 60 MB without the model, under 450 MB with it; Handy baseline 922 MB). See ADR 0001.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Parakeet TDT v3 is downloaded and loaded via FluidAudio on the Neural Engine
- [ ] A bundled Italian audio sample is transcribed and the Transcript is printed
- [ ] Footprint is measured idle without the model, idle with the model loaded, and right after a transcription
- [ ] Latency of a ~10 s and a ~60 s transcription is recorded, plus first-load (ANE compile) time
- [ ] A note with the numbers and a go/no-go decision is appended to this ticket under `## Comments`
- [ ] The spike code is not carried into the real project
