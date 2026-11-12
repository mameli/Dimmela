# Changelog

## 0.2.1

A lighter Dimmela, with more Modes and a smaller speech model to choose.

- **Four more built-in Modes**: *Email*, *Prompt* (an instruction for an AI assistant), *Shorter* and *Bullets*, next to Clean and Markdown. A new install gets them at its first launch; a Dimmela already set up keeps the Modes it has, and their [prompts](DimmelaCore/Sources/DimmelaCore/BuiltInModes.swift) can be copied from the source.
- **Parakeet Redux** in Settings › Transcription: the same languages in a download of 220 MB, against 490 (v3) and 632 (Ultra). A little less accurate on English; the first time it is prepared it takes several minutes.
- **A lighter menu**: *Default Mode* and *Provider* are only in Settings (the Mode chosen during a Dictation is still remembered), and *Copy Last*, *Reprocess Last* and *Reprocess Last With* have shorter names.
- Settings › Post-processing › **+** offers OpenRouter and Ollama; OpenAI, Mistral and LM Studio are still added with *New Profile* and their address.
- A *Support* section in *Settings › About*, with *Support Dimmela…*: an optional payment that supports Dimmela, in place of the Buy Me a Coffee note. The app is free and the same without it.
- *Settings › About* no longer links the prompts in `dimmela-config`, which are personal.

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
