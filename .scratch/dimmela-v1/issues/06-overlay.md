# 06: Overlay

**What to build:** While I dictate, a small pill appears at the bottom centre of the active screen showing the microphone level, the phase (recording, processing) and the current Mode (or that there is none). It never takes focus from the app I'm typing in, so the paste lands in the right place, and it disappears when the Dictation ends or is cancelled.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] The pill appears on Dictation start and disappears after the paste or on cancel
- [ ] The level meter follows my voice
- [ ] The pill switches to a processing indicator after recording ends
- [ ] The pill shows the current Mode name, or that no Post-processing will run
- [ ] The frontmost app keeps key focus throughout; the paste lands where the cursor was
- [ ] Controller tests cover the published overlay state across phases
