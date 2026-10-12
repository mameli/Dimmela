# 11: VAD: silence trim and no speech

**What to build:** Silero voice activity detection (via FluidAudio) trims leading and trailing silence before transcription. A Dictation with no detected speech, such as an accidental tap, pastes nothing, calls no LLM and is not stored.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Leading and trailing silence are trimmed before transcription
- [ ] A Dictation with no speech pastes nothing and makes no Post-processing request
- [ ] An empty Transcript after cleanup also ends the Dictation with nothing pasted
- [ ] Controller tests cover the no-speech and empty-Transcript paths
