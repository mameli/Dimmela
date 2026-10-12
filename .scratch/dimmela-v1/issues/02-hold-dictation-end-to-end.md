# 02: Hold Dictation end to end

**What to build:** The real project exists and I can dictate: Dimmela lives in the menu bar with a state icon (idle, recording, processing); holding `fn+space` records, releasing ends the Hold, the Transcript is pasted into the frontmost app with a trailing space and my clipboard restored. This slice sets up the app target (LSUIElement, bundle id `app.dimmela.Dimmela`, macOS 15, Apple Silicon, self-signed local signing as in Takku), the dependency-free `DimmelaCore` package with Swift Testing, CI adapted from Takku, the Dictation controller (the single test seam) with its Hold path, the CGEventTap shortcut monitor, the microphone recorder (no voice processing, 16 kHz mono in memory, device-change recovery), the Transcriber actor (Parakeet kept loaded, downloaded on first launch with its state shown in the menu), and the paster.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Holding `fn+space` records; releasing after 300 ms or more transcribes and pastes the Transcript at the cursor
- [ ] The pasted text ends with a trailing space and the previous clipboard content is restored
- [ ] The menu-bar icon reflects idle, recording and processing; the menu shows model state and Quit
- [ ] AirPods do not switch to call mode while recording
- [ ] Switching microphone between Dictations keeps dictation working
- [ ] Dimmela reports clearly when Accessibility permission is missing instead of failing silently
- [ ] Dictation controller tests (Swift Testing) cover the Hold path through injected `transcribe`, `paste` and clock fakes
- [ ] CI runs `swift test` for the core and an unsigned Debug build of the app
- [ ] A manual test checklist exists in the repo and covers this slice
- [ ] Footprint idle with the model loaded is re-measured and noted
