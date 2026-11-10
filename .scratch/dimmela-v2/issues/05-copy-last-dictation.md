# 05: Copy Last Dictation

**What to build:** A *Copy Last Dictation* item at the top level of the menu bar menu copies the final text of the most recent History entry, without opening the History submenu.

**Blocked by:** none

**Status:** ready-for-agent

- [x] Disabled when the History is empty
- [x] Copies the final text; when it differs from the Transcript, a second item (or ⌥ alternate) copies the Transcript
- [ ] Optional: a global shortcut for it. Decide if worth it

## Comments

### 2026-11-10: implemented (not committed)

- *Copy Last Dictation* at the top of the menu, disabled with an empty History; holding ⌥ turns it into *Copy Last Transcript*. No global shortcut.
