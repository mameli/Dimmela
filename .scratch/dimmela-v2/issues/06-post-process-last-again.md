# 06: Post-process the last Dictation again from the menu

**What to build:** A top-level item that runs Post-processing again on the most recent Dictation, with its Mode or another one. *Post-process Again With* already exists inside each History entry; this makes it one click away.

**Blocked by:** 01, 03

**Status:** ready-for-human

Mainly useful when retry and fallback still leave the Transcript pasted. Re-evaluate once 01 and 03 are in use: if failures are rare, close as wontfix.

- [x] *Post-process Last Dictation Again* with the same Mode, and a submenu for the others
- [x] When the last Dictation's Post-processing failed, the failure notification offers it too

## Comments

### 2026-11-11: implemented (not committed)

The user asked to go ahead without waiting for retry and fallback to be in use.

- Menu: *Post-process Last Dictation Again (Clean)*, with the Mode the Dictation had (or the Default Mode when it had none, or its Mode is no longer enabled), and *Post-process Last Dictation With* › every enabled Mode. As from the History, the result goes to the clipboard with a notification: the menu has just taken the focus.
- The "Post-processing failed, the Transcript was pasted instead" notification has a *Post-process Again* button (macOS shows it on hover, or always with the Alerts style).
- Dimmela is now the notification centre's delegate, so notifications also show while it is the active app.

To check by hand: turn the network off, dictate with a Mode, turn it back on, click *Post-process Again* in the notification.
