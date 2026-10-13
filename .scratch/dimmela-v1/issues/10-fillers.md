# 10: Fillers

**What to build:** Purely vocal Fillers ("ehm", "uhm", "mmh", a lone "eh") are removed from the Transcript, with whitespace and punctuation tidied afterwards. Words with meaning such as "cioè" or "tipo" are never removed.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] Fillers from the fixed list are removed from the Transcript
- [x] Spacing and punctuation around removed Fillers stay clean
- [x] "cioè", "tipo" and a non-isolated "eh" inside words are untouched
- [x] Controller tests cover removal and the words that must survive

## Comments

### 2026-10-13: done (commit a8c1699)

- Filler pattern: stretched `eh`, `ehm`, `uh`, `uhm`, `um`, `mmh`, `hmm`, as words of their own (hyphens and apostrophes count as part of a word).
- A Filler that opens a sentence passes its capital to the next word.
- A meaningful lone "eh" ("bello, eh?") is also removed, as specified.
