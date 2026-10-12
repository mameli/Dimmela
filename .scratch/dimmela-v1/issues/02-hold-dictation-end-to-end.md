# 02: Hold Dictation end to end

**What to build:** The real project exists and I can dictate: Dimmela lives in the menu bar with a state icon (idle, recording, processing); holding `fn+space` records, releasing ends the Hold, the Transcript is pasted into the frontmost app with a trailing space and my clipboard restored. This slice sets up the app target (LSUIElement, bundle id `app.dimmela.Dimmela`, macOS 15, Apple Silicon, self-signed local signing as in Takku), the dependency-free `DimmelaCore` package with Swift Testing, CI adapted from Takku, the Dictation controller (the single test seam) with its Hold path, the CGEventTap shortcut monitor, the microphone recorder (no voice processing, 16 kHz mono in memory, device-change recovery), the Transcriber actor (Parakeet kept loaded, downloaded on first launch with its state shown in the menu), and the paster.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Holding `fn+space` records; releasing after 300 ms or more transcribes and pastes the Transcript at the cursor
- [ ] The pasted text ends with a trailing space and the previous clipboard content is restored
- [x] The menu-bar icon reflects idle, recording and processing; the menu shows model state and Quit
- [ ] AirPods do not switch to call mode while recording
- [ ] Switching microphone between Dictations keeps dictation working
- [ ] Dimmela reports clearly when Accessibility permission is missing instead of failing silently
- [x] Dictation controller tests (Swift Testing) cover the Hold path through injected `transcribe`, `paste` and clock fakes
- [ ] CI runs `swift test` for the core and an unsigned Debug build of the app
- [x] A manual test checklist exists in the repo and covers this slice
- [x] Footprint idle with the model loaded is re-measured and noted

## Comments

### 2026-10-13: implemented (commit e295103)

- Verified by hand: `fn+space` Hold in TextEdit pastes the Transcript.
- Verified by the smoke test: `-transcribeFile` on 6 s of Italian runs in 94 ms.
- Footprint with Parakeet loaded: 38 MB idle and 46 MB right after a transcription.
- The model was seeded from Takku's cache. The first-launch download path (same FluidAudio call as Takku) has not been exercised on Dimmela yet; ticket 12 covers it.
- Still to check by hand, from `docs/TESTING.md`:
  - clipboard restored after the paste
  - trailing space
  - AirPods staying out of call mode
  - microphone switch between Dictations
  - notification when Accessibility is missing
- CI runs only once the repo has a GitHub remote.
- Design note: a fresh `AVAudioEngine` per Dictation. The microphone indicator shows only while dictating and device switches need no handling. If the first syllables get cut, keep one engine warm.
