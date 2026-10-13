# 08: History

**What to build:** Dimmela keeps my last 5 Dictations, each with its audio, Transcript, final text, Mode and time, in Application Support. From a History submenu in the menu bar I can copy the final text or the Transcript, or Post-process an entry again with another Mode, which copies the result to the clipboard and notifies me. Older entries and their audio are deleted as new ones arrive; cancelled Dictations are never stored.

**Blocked by:** 04

**Status:** ready-for-agent

- [x] Each completed Dictation creates a History entry with audio, Transcript, final text, Mode and timestamp
- [x] Only the last 5 entries are kept; the oldest entry and its audio are deleted when a sixth arrives
- [x] Cancelled Dictations are not stored
- [x] The History submenu offers copy final text, copy Transcript and Post-process again with any enabled Mode
- [x] Post-process again copies the new result to the clipboard and shows a notification
- [x] History survives an app restart
- [x] Controller tests cover entry creation, rotation, cancelled exclusion and Post-process again

## Comments

### 2026-10-13: done (commit 7fc0036)

- Verified by hand by the user.
- Post-processing again does not add a History entry; otherwise each retry would push out a real Dictation.
- A missing notification turned out to be notifications turned off in System Settings. The workaround attempted for it was reverted.
