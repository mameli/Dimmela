# 10: Fillers

**What to build:** Purely vocal Fillers ("ehm", "uhm", "mmh", a lone "eh") are removed from the Transcript, with whitespace and punctuation tidied afterwards. Words with meaning such as "cioè" or "tipo" are never removed.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Fillers from the fixed list are removed from the Transcript
- [ ] Spacing and punctuation around removed Fillers stay clean
- [ ] "cioè", "tipo" and a non-isolated "eh" inside words are untouched
- [ ] Controller tests cover removal and the words that must survive
