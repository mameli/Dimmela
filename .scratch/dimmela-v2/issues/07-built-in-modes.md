# 07: Built-in Modes

**What to build:** Dimmela ships with Modes that work without any Mode source:

- **Clean**: removes false starts and repetitions, resolves spoken corrections, fixes punctuation, keeps the language and the meaning (start from `dimmela-config/prompt.md`).
- **Markdown**: same cleaning, and turns what the user asks for into Markdown: "voglio scrivere una lista", "fai una tabella con…", headings, checklists, code.

**Blocked by:** none

**Status:** ready-for-human

- [x] Decide: bundled read-only Mode source, or copied to a folder the user can edit (and how updates reach an edited copy)
- [x] Shown in Settings › Modes like any other Mode, enabled at first run, Clean as the suggested Default Mode in onboarding
- [ ] Prompts tuned with the Post-processing log on real Italian and English dictations, both lists and tables
- [x] ADR 0002 still holds: they are prompt files like any other

## Comments

### 2026-11-11: implemented (not committed)

Decided without the user, to keep going (easy to change): editable copies in `~/.dimmela/modes`, replaced only while they hold a text Dimmela shipped (ADR 0006). Read-only in the bundle would change the Mode's path between builds and leave the prompts untunable.

- First launch: files written, folder added as a Mode source, both Modes enabled after the user's own. The Default Mode is not set by itself (with no working profile every Dictation would fail Post-processing); onboarding offers *Start Every Dictation with Clean*.
- Clean is dimmela-config's `prompt.md` without Handy's `Transcript: ${output}` tail. Markdown adds a MARKDOWN FORMATTING section, inline code for filenames, a verification line and "never describe the dictation".
- Markdown tuned with Claude Haiku 5.5 (thinking off) through Claude Code on 9 made-up dictations (lists, a table of people, a comparison table, a checklist, numbered steps in English, headings with sections, a plain message, an enumeration inside a sentence, a filename): all formatted as wanted. Fixes from the runs: keep what the list is about ("Lista della spesa:"), checklist boxes whenever "checklist"/"cose da fare" is said, and no narration (once in 3 runs before the rule, 0 in 5 after).

Left for the user: tune on real dictations from `~/.dimmela/post-processing.jsonl`, which I did not send to a model; one ambiguity seen: "decisioni lista rilascio venerdì" keeps "Lista" in the item.
