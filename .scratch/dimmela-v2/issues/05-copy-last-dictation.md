# 05: Copy Last Dictation

**What to build:** A *Copy Last Dictation* item at the top level of the menu bar menu copies the final text of the most recent History entry, without opening the History submenu.

**Blocked by:** none

**Status:** ready-for-human

- [x] Disabled when the History is empty
- [x] Copies the final text; when it differs from the Transcript, a second item (or ⌥ alternate) copies the Transcript
- [x] Optional: a global shortcut for it. Decided: not worth it (see below)

## Comments

### 2026-11-10: implemented (not committed)

- *Copy Last Dictation* at the top of the menu, disabled with an empty History; holding ⌥ turns it into *Copy Last Transcript*. No global shortcut.

### 2026-11-11: no global shortcut

Decided without one. Every Dictation is pasted already, so copying the last one again is for when the paste went to the wrong place or failed, which is rare and one click away in the menu. A shortcut would need a key combination of its own: fn+Space's variants are taken (with ⌘, ⌃ or ⌥ it is left to the system; shift and the digits act during a Dictation), and anything else is one more thing to configure and to explain. Reopen if users ask for it.
