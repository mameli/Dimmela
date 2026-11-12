# Changelog

## Unreleased

- A *Support* section in *Settings › About*, with *Support Dimmela…*: an optional payment that supports Dimmela, in place of the Buy Me a Coffee note. The app is free and the same without it.

## 0.2.0

- **Provider profiles**: keep several providers, each with its own key, and switch between them from the menu. A busy provider is asked again; if it still fails, the profiles marked **Fallback** are tried in order, and after 20 seconds the Transcript is pasted.
- **Your coding agent as the provider**: Claude Code, Codex, GitHub Copilot, OpenCode or Pi, with the plan you already pay for and no key in Dimmela. Each run uses none of your agent's settings and keeps nothing.
- **Built-in Modes**: Clean and Markdown, two prompts to start with, in `~/.dimmela/modes` to edit as your own.
- **Copy Last Dictation** and **Reprocess Last Dictation** in the menu, also with another Mode; the notification of a failed Post-processing has a **Reprocess** button.
- **Parakeet Ultra**, a larger speech model, in Settings › Transcription.
- **A new welcome tour**, with a test Dictation, and a card to drag Dimmela into System Settings' Accessibility list.
- Settings: **About** with updates and **Report a Problem**; Reasoning, Extra parameters and the Post-processing log under **Advanced**; **Edit With** and **Move to Trash** for each Mode.
- A shorter menu: History, Copy, Reprocess, Default Mode, Settings.
- **Updates itself**: when a new version is out, *Dimmela … is available…* in the menu installs it and opens Dimmela again, never in the middle of a Dictation. This is the last version to install by hand.
- Installed from a disk image: drag Dimmela into Applications.
