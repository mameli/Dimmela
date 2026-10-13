# Testing

Domain behaviour is covered by `swift test` in `DimmelaCore`. What depends on macOS (keyboard, microphone, speech model, pasteboard) is checked by hand with this list before a release, and after changing the piece concerned.

## Build and run

```bash
xcodebuild -project Dimmela.xcodeproj -scheme Dimmela -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Dimmela.app
```

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` first, so macOS keeps the permissions across builds.

## Smoke test (Debug builds)

Transcribe a file without microphone or keyboard. It prints the Transcript, the time and the memory footprint:

```bash
build/DerivedData/Build/Products/Debug/Dimmela.app/Contents/MacOS/Dimmela -transcribeFile <audio file>
```

## Checklist

### Hold Dictation (ticket 02)

- [ ] First launch asks for the microphone and shows the Accessibility prompt; the menu offers "Allow Accessibility…" until it is granted, then disappears without relaunching.
- [ ] The menu shows the speech model state and then "Ready: hold fn+Space to dictate".
- [ ] In TextEdit, hold `fn+space`, speak Italian, release: the menu-bar icon goes recording → processing → idle and the Transcript appears at the cursor followed by a space.
- [ ] No space is typed by the shortcut itself, also when holding it for several seconds.
- [ ] Copy something before dictating: after the paste the clipboard still holds it.
- [ ] Dictate with AirPods connected: they stay in high-quality mode (no call-mode audio drop).
- [ ] Switch the input device in System Settings between two Dictations: the second still works.
- [ ] Remove Dimmela from Accessibility and dictate: a notification explains the paste needs Accessibility.
- [ ] `fn+space` with `⌘`, `⌃` or `⌥` held does not start a Dictation.
- [ ] Footprint idle with the model loaded (`footprint <pid>`) stays well under 450 MB.

### Lock and Esc (ticket 03)

- [ ] A quick tap of `fn+space` starts a Lock: the icon stays on recording with no key held; the next tap ends it and the Transcript is pasted.
- [ ] Holding `fn+space` for about a second still works as a Hold.
- [ ] `Esc` while holding `fn+space`, during a Lock, or while the icon shows processing: nothing is pasted and the icon goes back to idle.
- [ ] The `Esc` that cancels a Dictation does not reach the frontmost app (e.g. it does not close a dialog or leave full screen).
- [ ] With no Dictation in progress `Esc` works normally everywhere.
- [ ] `fn+space` pressed while the icon shows processing does not start a new Dictation.

### Post-processing with a prompt-file Mode (ticket 04)

- [ ] Settings › Post-processing: paste an OpenRouter key, Save key, Test connection: the provider answers.
- [ ] The key is in Keychain Access under "Dimmela: provider API key", not in Dimmela's preferences.
- [ ] Settings › Modes: Add Folder… with the `handy-config` folder; its prompt files are listed, README excluded.
- [ ] Enable some Modes, drag to reorder, choose a Default Mode; the menu's Default Mode picker shows the same.
- [ ] `shift+fn+space` in TextEdit: the LLM's answer is pasted. Plain `fn+space` still pastes only the Transcript.
- [ ] Edit the Default Mode's file (e.g. "answer in uppercase"); the next Dictation follows the edit without relaunching.
- [ ] Turn Wi-Fi off and dictate with `shift+fn+space`: the Transcript is pasted and a notification explains why.
- [ ] Rename the Default Mode's file and dictate: the Transcript is pasted and a notification explains why.

### Skills as Modes (ticket 05)

- [ ] Settings › Modes › Add Folder… with `~/.claude/skills` (⌘⇧G to type the path, ⌘⇧. to show hidden folders): skills are listed by name, also those that are symbolic links; coding skills appear only under Available.
- [ ] Enable `mameli-x-voice`, make it the Default Mode, dictate in Italian with `shift+fn+space`: an English X post is pasted, with no preamble or quotes around it.
- [ ] A skill with `references/` (e.g. `stop-slop`) works as a Mode.
- [ ] Rename an enabled skill's folder: Settings shows it as Missing, and dictating with it pastes the Transcript with a notification.

### Overlay (ticket 06)

- [ ] `fn+space`: a dark pill appears at the bottom centre of the screen with the pointer, with red bars that follow the voice and "Transcript".
- [ ] `shift+fn+space` with a Default Mode: the pill shows the Mode's name.
- [ ] After recording, the bars become three pulsing white dots until the paste; then the pill disappears.
- [ ] `Esc` hides the pill at once.
- [ ] Dictating into TextEdit, the cursor stays in TextEdit and the paste lands there; the pill cannot be clicked.
- [ ] With two displays, the pill shows on the one with the pointer; it also shows over a full-screen app.
- [ ] With Reduce Motion on, the bars still move but without animation and the dots stay still.

### Mode digits and Mode list (ticket 07)

- [ ] During a Hold, press `2`: the list of Modes appears above the pill with the second highlighted, the pill shows its name, and the LLM's answer for that Mode is pasted.
- [ ] `shift+fn+space` then `0`: only the Transcript is pasted.
- [ ] Press `1` then `3`: the third Mode is used. A digit beyond the enabled Modes changes nothing.
- [ ] In a Lock, digits work the same way.
- [ ] The digits pressed during a Dictation never appear in TextEdit; with no Dictation they type normally, also right after the paste.
- [ ] Holding `shift` during a Dictation shows the list; releasing it hides it (unless a digit was pressed).
- [ ] With more than nine enabled Modes, only the first nine are listed.
