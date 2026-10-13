# 07: Mode digits and Mode list in the overlay

**What to build:** During a Dictation (Hold or Lock) I press `1`–`9` to apply the enabled Mode at that position to this Dictation only, or `0` for no Post-processing; the last digit wins, digits for unused positions are ignored. Digits are swallowed only during a Dictation and type normally otherwise. `shift` opens and closes the numbered list of Modes above the pill; ↑/↓ move through it (Transcript first) and a digit or `Return` closes it. The pill shows the chosen Mode. (Revised after the first try: `shift+fn+space` is gone, every Dictation starts with the Default Mode.)

**Blocked by:** 03, 05, 06

**Status:** ready-for-agent

- [x] Digits 1–9 select the matching enabled Mode for the current Dictation; `0` selects none
- [x] The last digit pressed wins; digits with no enabled Mode are ignored
- [x] Digits never reach the frontmost app during a Dictation and behave normally outside one
- [x] Works in both Hold and Lock, including overriding the Default Mode
- [x] `shift` toggles the list; a digit or `Return` closes it; arrows and `Return` are swallowed only while it is open; only the first nine enabled Modes are listed
- [x] Controller tests cover digit selection, `0`, last-wins, unmapped digits, swallow/pass-through and list visibility

## Comments

### 2026-10-13: done (commit 73ebc07)

- Verified by hand by the user.
- After the first try the user dropped `shift+fn+space`: every Dictation starts with the Default Mode (which can be None), and `shift` toggles the Mode list.
- In the open list, ↑/↓ move the choice and a digit or `Return` closes it.
- `Esc` still cancels the whole Dictation, also with the list open (the user's choice).
