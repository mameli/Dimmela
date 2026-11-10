# Built-in Modes are prompt files copied where the user can edit them

Dimmela ships two Modes, Clean and Markdown, so Post-processing works without a Mode source of the user's. They are prompt files like any other (ADR 0002), written at the first launch in `~/.dimmela/modes`, next to the Vocabulary. That folder becomes a Mode source and both Modes are enabled after the user's own, so the digits the user already knows do not move. The Default Mode is not set by itself: without a working Provider profile every Dictation would fail Post-processing; onboarding offers Clean as the Default Mode with one click.

Keeping them read-only inside the app was rejected: a Mode is identified by its path, which changes between builds and installs, and the user could not tune the prompts, which is what the Post-processing log is for.

## Consequences

- Dimmela replaces a file only while it holds a text Dimmela wrote: `BuiltInModes.earlierVersions` lists, per file, the SHA-256 prefix of every text shipped before. A file the user edited stays as it is, and so does a file they deleted: it is written only at the first launch. Changing a prompt therefore means adding the current text's version to that list first, as a test checks.
- An edited copy no longer gets improvements; the user can delete it and copy the new text from Dimmela's source, or diff it by hand.
- Clean starts from dimmela-config's `prompt.md`; Markdown is the same cleaning with a section on lists, numbered lists, checklists, tables and headings, applied when the user asks for them while dictating ("voglio scrivere una lista", "fai una tabella con…") or when the content clearly is one.
