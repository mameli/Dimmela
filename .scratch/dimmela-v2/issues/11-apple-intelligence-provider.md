# 11: Apple Intelligence as a Provider profile

**What to build:** A Provider profile that runs Apple Intelligence's on-device model through Foundation Models, as Takku does (`AppleIntelligence`, `AppleIntelligenceModel`, Takku's ADR 0013): free, no key, the text never leaves the Mac.

**Blocked by:** none

**Status:** wontfix

## Comments

### 2026-11-11: measured first, not built

On this Mac (macOS 27, model available, 8,192 tokens of context), `SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)`, temperature 0.3, one new session per Dictation as in Takku, on the 9 made-up Dictations used to tune the Markdown Mode (issue 07). Fast: 0.4–2.6 s. Not good enough:

- **Clean** (dimmela-config's prompt): mostly leaves the text as dictated, without capitals or punctuation ("ciao luca ti scrivo per dirti…"); "quarantadue", "chiocciola", "underscore" stay as words; it makes a table and a numbered list nobody asked for.
- **Markdown**: changes numbers in the comparison table (490 MB → "449 mega", 632 → "362 meg"); turns "ci servono latte, uova e farina" into a list; no checklist boxes for "come checklist"; keeps "Lista" inside the items.
- **A short prompt written for a small model** (6 rules): better punctuation, but still "seicentotrentadue mega" → "32.42 meg", the self-correction "farina eh no la farina no" ignored, dictated e-mail addresses left as words.

A Dictation whose numbers silently change is worse than the Transcript pasted as it is, so it is not offered, not even as a fallback (a failed Post-processing already pastes the Transcript). Look again with a new macOS model: rerun the cases in `.scratch` notes above with both built-in Modes; numbers must never change.
