# 03: Lock and Esc

**What to build:** A short tap of `fn+space` (under 300 ms) starts a Lock that keeps recording hands-free until the next tap. `Esc` cancels the current Dictation, while recording or while processing, and nothing is pasted or stored. Outside a Dictation `Esc` reaches the frontmost app normally. A new `fn+space` while a Dictation is processing is ignored.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] A tap under 300 ms starts a Lock; the next press ends it and the Transcript is pasted
- [x] Recording starts on key down, so no words are lost while deciding between Hold and Lock
- [x] `Esc` during recording or processing cancels the Dictation and pastes nothing
- [x] `Esc` is swallowed only while a Dictation is in progress and passes through otherwise
- [x] `fn+space` during processing is ignored
- [x] Controller tests cover Hold vs Lock at the threshold, `Esc` in each phase, the ignore-while-processing rule and the swallow/pass-through decision
- [x] Manual checklist updated

## Comments

### 2026-10-13: done (commit 78f9086)

Verified by hand by the user: Lock, Hold, Esc in each phase, Esc passing through outside a Dictation, and the shortcut ignored while processing. Covered by 10 new controller tests.
