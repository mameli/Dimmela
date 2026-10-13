# 09: Vocabulary

**What to build:** In a Vocabulary settings section I manage terms and their known variants (e.g. "Jira" with "gira"). Variants are replaced deterministically in the Transcript, case-insensitively and on word boundaries, with no biasing passed to the speech engine (ADR 0003). When a Mode is applied, the Post-processing request also lists the Vocabulary terms so the LLM can repair what substitution missed.

**Blocked by:** 04

**Status:** ready-for-agent

- [x] Settings has a Vocabulary section to add, edit and remove terms and variants
- [x] Known variants are replaced in the Transcript on word boundaries, case-insensitively
- [x] Words that merely contain a variant are not touched
- [x] Every Post-processing request includes a line listing the Vocabulary terms
- [x] Controller tests cover substitution and the Vocabulary line in the request

## Comments

### 2026-10-13: done (commit 429f7b2)

- Verified by hand by the user.
- Vocabulary parsing and substitution are ported from Takku. Settings uses a text editor with Takku's line format: `- term = variants | description`.
