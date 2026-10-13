# 06: Overlay

**What to build:** While I dictate, a small pill appears at the bottom centre of the active screen showing the microphone level, the phase (recording, processing) and the current Mode (or that there is none). It never takes focus from the app I'm typing in, so the paste lands in the right place, and it disappears when the Dictation ends or is cancelled.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] The pill appears on Dictation start and disappears after the paste or on cancel
- [x] The level meter follows my voice
- [x] The pill switches to a processing indicator after recording ends
- [x] The pill shows the current Mode name, or that no Post-processing will run
- [x] The frontmost app keeps key focus throughout; the paste lands where the cursor was
- [x] Controller tests cover the published overlay state across phases

## Comments

### 2026-10-13: done

- Verified by hand by the user.
- While processing, the pill shows three white dots that pulse one after the other on a 1.6 s cycle (the user's choice), instead of the system spinner, which was invisible on the dark pill.
- The dots stay still with Reduce Motion.
