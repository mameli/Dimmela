# 05: Skills as Modes

**What to build:** Skills in my Mode sources (any folder with a `SKILL.md`, e.g. `~/.claude/skills`) appear alongside prompt files, named after their frontmatter `name` (or folder name), and can be enabled and ordered. A skill used as a Mode is sent as the fixed Dimmela preamble plus the `SKILL.md` body without frontmatter plus every `references/*.md` file in name order (ADR 0002). Scripts and other files are ignored. A Mode whose files have disappeared is flagged as missing in the settings and its Dictations fall back to the Transcript.

**Blocked by:** 04

**Status:** ready-for-agent

- [x] Skills from a Mode source are listed with their readable name and can be enabled, ordered and chosen as Default Mode
- [x] The request for a skill Mode contains the preamble, the frontmatter-free `SKILL.md` and the `references/*.md` files in order
- [x] Coding skills stay out of the Modes unless explicitly enabled
- [x] A deleted or moved Mode is flagged as missing; a Dictation with it pastes the Transcript and notifies
- [x] Tests on temporary folders cover skills with and without `references/`, frontmatter parsing, README exclusion and missing files

## Comments

### 2026-10-13: done (commit 51308af)

Verified by hand by the user with the skills in `~/.claude/skills`. The provider timeout went back to 30 s (60 s total), after the user tried 5 s.
