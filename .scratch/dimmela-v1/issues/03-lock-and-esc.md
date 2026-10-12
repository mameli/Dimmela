# 03: Lock and Esc

**What to build:** A short tap of `fn+space` (under 300 ms) starts a Lock that keeps recording hands-free until the next tap. `Esc` cancels the current Dictation, while recording or while processing, and nothing is pasted or stored. Outside a Dictation `Esc` reaches the frontmost app normally. A new `fn+space` while a Dictation is processing is ignored.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] A tap under 300 ms starts a Lock; the next press ends it and the Transcript is pasted
- [ ] Recording starts on key down, so no words are lost while deciding between Hold and Lock
- [ ] `Esc` during recording or processing cancels the Dictation and pastes nothing
- [ ] `Esc` is swallowed only while a Dictation is in progress and passes through otherwise
- [ ] `fn+space` during processing is ignored
- [ ] Controller tests cover Hold vs Lock at the threshold, `Esc` in each phase, the ignore-while-processing rule and the swallow/pass-through decision
- [ ] Manual checklist updated
