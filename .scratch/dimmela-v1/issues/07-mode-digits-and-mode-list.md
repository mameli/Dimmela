# 07: Mode digits and Mode list in the overlay

**What to build:** During a Dictation (Hold or Lock) I press `1`–`9` to apply the enabled Mode at that position to this Dictation only, or `0` for no Post-processing; the last digit wins, digits for unused positions are ignored. Digits are swallowed only during a Dictation and type normally otherwise. The numbered list of Modes appears above the pill when I press a digit or hold `shift`, and the pill shows the chosen Mode.

**Blocked by:** 03, 05, 06

**Status:** ready-for-agent

- [ ] Digits 1–9 select the matching enabled Mode for the current Dictation; `0` selects none
- [ ] The last digit pressed wins; digits with no enabled Mode are ignored
- [ ] Digits never reach the frontmost app during a Dictation and behave normally outside one
- [ ] Works in both Hold and Lock, including overriding the Default Mode chosen by `shift`
- [ ] The numbered list appears on a digit press or while `shift` is held; only the first nine enabled Modes are listed
- [ ] Controller tests cover digit selection, `0`, last-wins, unmapped digits, swallow/pass-through and list visibility
