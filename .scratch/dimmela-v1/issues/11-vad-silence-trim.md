# 11: VAD: silence trim and no speech

**What to build:** Silero voice activity detection (via FluidAudio) trims leading and trailing silence before transcription. A Dictation with no detected speech, such as an accidental tap, pastes nothing, calls no LLM and is not stored.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] Leading and trailing silence are trimmed before transcription
- [x] A Dictation with no speech pastes nothing and makes no Post-processing request
- [x] An empty Transcript after cleanup also ends the Dictation with nothing pasted
- [x] Controller tests cover the no-speech and empty-Transcript paths

## Comments

### 2026-10-13: done (commit 42aed7d)

- Verified by hand by the user and by the smoke test: speech range found with a small margin on padded audio, `none` on silence, about 8 ms.
- Silero threshold is 0.5 (FluidAudio defaults to 0.85, which risks dropping quiet speech).
- If the detector is unavailable, all the audio is transcribed.
- Footprint with Parakeet and Silero loaded: 41 MB.
