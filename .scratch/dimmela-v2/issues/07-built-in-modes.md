# 07: Built-in Modes

**What to build:** Dimmela ships with Modes that work without any Mode source:

- **Clean**: removes false starts and repetitions, resolves spoken corrections, fixes punctuation, keeps the language and the meaning (start from `dimmela-config/prompt.md`).
- **Markdown**: same cleaning, and turns what the user asks for into Markdown: "voglio scrivere una lista", "fai una tabella con…", headings, checklists, code.

**Blocked by:** none

**Status:** needs-triage

- [ ] Decide: bundled read-only Mode source, or copied to a folder the user can edit (and how updates reach an edited copy)
- [ ] Shown in Settings › Modes like any other Mode, enabled at first run, Clean as the suggested Default Mode in onboarding
- [ ] Prompts tuned with the Post-processing log on real Italian and English dictations, both lists and tables
- [ ] ADR 0002 still holds: they are prompt files like any other

## Comments
