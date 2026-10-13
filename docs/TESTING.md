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
- [ ] With a Default Mode, `fn+space` in TextEdit pastes the LLM's answer; with Default Mode None it pastes only the Transcript.
- [ ] Edit the Default Mode's file (e.g. "answer in uppercase"); the next Dictation follows the edit without relaunching.
- [ ] Turn Wi-Fi off and dictate with a Default Mode: the Transcript is pasted and a notification explains why.
- [ ] Rename the Default Mode's file and dictate: the Transcript is pasted and a notification explains why.

### Skills as Modes (ticket 05)

- [ ] Settings › Modes › Add Folder… with `~/.claude/skills` (⌘⇧G to type the path, ⌘⇧. to show hidden folders): skills are listed by name, also those that are symbolic links; coding skills appear only under Available.
- [ ] Enable `mameli-x-voice`, make it the Default Mode, dictate in Italian: an English X post is pasted, with no preamble or quotes around it.
- [ ] A skill with `references/` (e.g. `stop-slop`) works as a Mode.
- [ ] Rename an enabled skill's folder: Settings shows it as Missing, and dictating with it pastes the Transcript with a notification.

### Overlay (ticket 06)

- [ ] `fn+space`: a dark pill appears at the bottom centre of the screen with the pointer, with red bars that follow the voice and "Transcript".
- [ ] With a Default Mode, the pill shows the Mode's name.
- [ ] After recording, the bars become three pulsing white dots until the paste; then the pill disappears.
- [ ] `Esc` hides the pill at once.
- [ ] Dictating into TextEdit, the cursor stays in TextEdit and the paste lands there; the pill cannot be clicked.
- [ ] With two displays, the pill shows on the one with the pointer; it also shows over a full-screen app.
- [ ] With Reduce Motion on, the bars still move but without animation and the dots stay still.

### Mode digits and Mode list (ticket 07)

- [ ] During a Hold, press `2`: the pill shows the second Mode's name (no list opens) and the LLM's answer for that Mode is pasted.
- [ ] With a Default Mode, dictate and press `0`: only the Transcript is pasted.
- [ ] Press `1` then `3`: the third Mode is used. A digit beyond the enabled Modes changes nothing.
- [ ] In a Lock, digits work the same way.
- [ ] The digits pressed during a Dictation never appear in TextEdit; with no Dictation they type normally, also right after the paste.
- [ ] `shift` during a Dictation opens the list with the current Mode highlighted; `shift` again closes it.
- [ ] With the list open, ↑/↓ move the highlight (from Transcript to the last Mode) and the pill follows; `Return` or a digit closes the list. Arrows and `Return` never reach TextEdit while the list is open, and work normally otherwise.
- [ ] With more than nine enabled Modes, only the first nine are listed.

### History (ticket 08)

- [ ] After a Dictation, the menu has a History submenu; the entry shows time, Mode and the start of the text.
- [ ] Copy Text and Copy Transcript put the right text on the clipboard (Copy Transcript only when they differ).
- [ ] Post-process Again With another Mode: a notification says the new text is on the clipboard, and ⌘V pastes it.
- [ ] After six Dictations only five entries are listed; `~/Library/Application Support/Dimmela/History` holds five folders, each with `entry.json` and a playable `audio.wav`.
- [ ] A Dictation cancelled with `Esc` does not appear. The History is still there after quitting and reopening Dimmela.

### Vocabulary (ticket 09)

- [ ] Settings › Vocabulary: write `- Jira = ira, gira | the issue tracker at work`; the count shows 1 entry. The text is still there after reopening Settings and after relaunching.
- [ ] Dictate "apro ira" with Default Mode None: "apro Jira" is pasted. A word that only contains a variant ("Lira", "girare") is untouched.
- [ ] With a Default Mode, the History's Copy Transcript shows the corrected term.
- [ ] Lines that do not start with `- ` are ignored, so notes can sit in the list.

### Fillers (ticket 10)

- [ ] Dictate "allora, ehm, volevo dire una cosa" with Default Mode None: no "ehm" and no stray comma in the pasted text.
- [ ] Start a Dictation with "ehm," or "mmh…": the text starts with the next word, capitalized.
- [ ] "cioè" and "tipo" stay in the text.

### Voice activity detection (ticket 11)

- [ ] Smoke test: `-transcribeFile` on a file with a second of silence around the speech prints a speech range inside the file; on a silent file it prints `speech none`.
- [ ] A quick accidental tap of `fn+space` followed by a second tap without speaking pastes nothing and leaves no History entry.
- [ ] Speaking quietly or after a long pause is still transcribed.
- [ ] A Dictation with long pauses in the middle keeps everything said (only the silence before and after is cut).

### Onboarding and model management (ticket 12)

To see the first launch again: `defaults delete app.dimmela.Dimmela onboardingDone`, or in a Debug build add `-showWelcome YES`. To start from zero, also remove Dimmela from the Microphone and Accessibility lists (`tccutil reset Microphone app.dimmela.Dimmela`, `tccutil reset Accessibility app.dimmela.Dimmela`) and delete `~/Library/Application Support/Dimmela/Models`.

- [ ] First launch: the welcome window opens in front; no permission prompt appears by itself.
- [ ] Allow the Microphone: the system prompt appears, then the window comes back to the front and step 1 is ticked.
- [ ] Allow Accessibility: System Settings opens; after turning Dimmela on and coming back, step 2 is ticked and `fn+space` works without relaunching.
- [ ] Allow Notifications: step 3 is ticked; if denied, Open System Settings goes to the Notifications pane.
- [ ] With no model on disk, step 4 shows the download progress, then "Preparing the model for this Mac", then ready (about a minute on an M3 Pro).
- [ ] Done closes the window; it does not open at the next launch and "Set Up Dimmela…" leaves the menu.
- [ ] Settings › Transcription: Delete the Model removes it (the next Dictation downloads it again); Download Again replaces it.
- [ ] Quit Dimmela halfway through the download and relaunch: the download starts again from scratch.

### Launch at login (ticket 13)

- [ ] Settings › General shows the icon, the name and the version, and "Open at login".
- [ ] Turn it on: Dimmela appears in System Settings › General › Login Items. If macOS asks for approval, the toggle shows "Open Login Items".
- [ ] Log out and back in: Dimmela is in the menu bar and the menu says Ready without opening it by hand.
- [ ] Turn it off: Dimmela leaves the Login Items.
- [ ] The welcome window has the same toggle under Optional.

### Update check and problem report (ticket 14)

- [ ] With a GitHub release of `mameli/Dimmela` newer than the running version, the menu shows "Dimmela X is available…" and opens the release page. Turned off in Settings › General, no request is made.
- [ ] Report a Problem…: a "Dimmela report <date>.txt" file is shown in Finder with version, Mac, install method, Post-processing model (no address, no key) and recent logs; the GitHub bug form opens with the same fields filled in.
