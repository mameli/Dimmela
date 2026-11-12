# Testing

Domain behaviour is covered by `swift test` in `DimmelaCore`. What depends on macOS (keyboard, microphone, speech model, pasteboard) is checked by hand with this list before a release, and after changing the piece concerned.

## Build and run

```bash
xcodebuild -project Dimmela.xcodeproj -scheme Dimmela -configuration Debug -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Dimmela.app
```

Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` first, so macOS keeps the permissions across builds.

The Debug build (signed with the local certificate) and the released app (signed with Developer ID) are different apps for macOS: each needs its own Microphone and Accessibility grant. When switching from one to the other, remove Dimmela from Privacy & Security › Accessibility (and Microphone if needed) and allow it again.

If notifications or permission prompts show macOS's grid placeholder instead of Dimmela's icon, the system icon cache kept the icon of a build that had none. Clearing it fixes it: `rm -rf "$(getconf DARWIN_USER_CACHE_DIR)com.apple.iconservices"`, `sudo rm -rf /Library/Caches/com.apple.iconservices.store`, then restart the Mac. Several copies of Dimmela registered at once (the Debug, Release and installed builds share the bundle id) make it more likely.

## Logs

Dimmela writes every step to `~/Library/Logs/Dimmela/Dimmela.log` (also in Console › Log Reports): launch and permissions, start and end of each Dictation with the audio length and the Mode, speech found, transcription time, Post-processing requests (model, on this Mac or remote, reasoning, whether there are Extra parameters, HTTP status, time), paste, `Esc`, errors. Never the Transcript, the text, the provider's address, the key or the Extra parameters. Past 512 KB the file becomes `Dimmela.1.log` and a new one starts, so the two stay under 1 MB. *Report a Problem…* includes both.

```bash
tail -f ~/Library/Logs/Dimmela/Dimmela.log
```

## Smoke test (Debug builds)

Transcribe a file without microphone or keyboard. It prints the Transcript, the time and the memory footprint:

```bash
build/DerivedData/Build/Products/Debug/Dimmela.app/Contents/MacOS/Dimmela -transcribeFile <audio file>
```

To look at one page of the welcome tour without clicking through it (`-welcomePage` 0–4: hello, setup, try it, Modes, small things):

```bash
build/DerivedData/Build/Products/Debug/Dimmela.app/Contents/MacOS/Dimmela -showWelcome YES -welcomePage 2
```

## Checklist

### Hold Dictation (ticket 02)

- [ ] First launch asks for the microphone and shows the Accessibility prompt; the menu offers "Allow Accessibility…" until it is granted, then disappears without relaunching.
- [ ] The menu shows the speech model state and then "Ready: hold fn+Space to dictate".
- [ ] In TextEdit, hold `fn+space`, speak Italian, release: the menu-bar icon goes recording → processing → idle and the Transcript appears at the cursor followed by a space.
- [ ] No space is typed by the shortcut itself, also when holding it for several seconds.
- [ ] Copy something before dictating: after the paste the clipboard still holds it.
- [ ] Dictate with AirPods connected: they stay in high-quality mode (no call-mode audio drop).
- [ ] Dictate with the MacBook's built-in microphone (three channels) and with a one-channel microphone (AirPods): both are transcribed.
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
- [ ] Reasoning on OpenRouter set to Off, then High: Test connection still answers, a little slower with High.
- [ ] Extra parameters: type `{"reasoning_effort": "xhigh"}` by hand (with smart quotes on in System Settings › Keyboard): the quotes stay straight and no error shows. Remove the closing brace: a red message, Test connection disabled; quit and reopen Settings: the last valid parameters are back.
- [ ] Settings › Post-processing › Keep a Post-processing log on, then dictate with a Mode: `~/.dimmela/post-processing.jsonl` gets one line with the Transcript, the answer, the Mode, `promptVersion`, model and reasoning. Edit the prompt file and dictate again: the new line has another `promptVersion`. Post-process a History entry again from the menu: its line has `"isAgain":true`. Add `"comment":"…"` by hand to a line, save, dictate again: the comment is still there. Turn the log off: no new lines.
- [ ] Extra parameters `{"reasoning_effort": "banana"}` on a provider that checks it: Test connection fails with the provider's message followed by "Settings › Post-processing sets Extra parameters."
- [ ] Settings › Modes: Add Folder… with the `handy-config` folder; its prompt files are listed, README excluded.
- [ ] Enable some Modes, drag to reorder, choose a Default Mode.
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
- [ ] The Mode chosen during a Dictation (digit or arrows) is the Default Mode for the next one, and Settings shows it; after `0`, the next Dictation gives the Transcript alone.

### History (ticket 08)

- [ ] After a Dictation, the menu has a History submenu; the entry shows time, Mode and the start of the text.
- [ ] Copy Text and Copy Transcript put the right text on the clipboard (Copy Transcript only when they differ).
- [ ] History › Reprocess With another Mode: a notification says the new text is on the clipboard, and ⌘V pastes it.
- [ ] After six Dictations only five entries are listed; `~/Library/Application Support/Dimmela/History` holds five folders, each with `entry.json` and a playable `audio.wav`.
- [ ] A Dictation cancelled with `Esc` does not appear. The History is still there after quitting and reopening Dimmela.

### Vocabulary (ticket 09)

- [ ] At launch `~/.dimmela/vocabulary.md` exists: the syntax on top, then the entries once written in Settings (if any).
- [ ] Settings › Transcription › Vocabulary shows how many terms were read and the first ones ("No terms yet" if none); the footer names the file and shows the syntax. Edit Vocabulary With lists the apps that edit text, with icons, the system's default first and marked. After saving and coming back, the count and the terms are updated; a line without `- ` does not show up.
- [ ] Add `- Jira = ira, gira | the issue tracker at work` and dictate "apro ira" with Default Mode None, without relaunching: "apro Jira" is pasted. A word that only contains a variant ("Lira", "girare") is untouched.
- [ ] With a Default Mode, the History's Copy Transcript shows the corrected term.
- [ ] Lines that do not start with `- ` are ignored, so notes can sit in the file.

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
- [ ] Done closes the window; it does not open at the next launch; Settings › About › Welcome Tour… opens it again.
- [ ] Settings › Transcription: Delete the Model removes it (the next Dictation downloads it again); Download Again replaces it.
- [ ] Quit Dimmela halfway through the download and relaunch: the download starts again from scratch.

### Launch at login (ticket 13)

- [ ] Settings › General shows "Open at login", "Check for updates" and Permissions: Microphone, Accessibility and Notifications, each Allowed or with the button to allow it; turned on in System Settings, the row says Allowed on coming back.
- [ ] Turn it on: Dimmela appears in System Settings › General › Login Items. If macOS asks for approval, the toggle shows "Open Login Items".
- [ ] Log out and back in: Dimmela is in the menu bar and the menu says Ready without opening it by hand.
- [ ] Turn it off: Dimmela leaves the Login Items.
- [ ] The welcome window has the same toggle under Optional.

### Update check and problem report (ticket 14)

- [ ] With a GitHub release of `mameli/Dimmela` newer than the running version (and its appcast.xml), the menu shows "Dimmela X is available…"; choosing it opens Sparkle's window, and Install Update replaces Dimmela and opens it again. During a Dictation the relaunch waits for it to end. Turned off in Settings › General, no daily request is made; Settings › About › Check Now still checks. In a Debug build: `-testUpdateFeed <URL>` with an appcast served locally.
- [ ] Settings › About › Report a Problem…: a "Dimmela report <date>.txt" file is shown in Finder with version, Mac, install method, Post-processing model (no address, no key) and recent logs; the GitHub bug form opens with the same fields filled in.

### Disk image

- [ ] `scripts/release.sh --dry-run`, then open `build/release/Dimmela-<version>.dmg`: the green window says "Drag Dimmela into Applications", Dimmela on the left, Applications on the right, the arrow between them, the shortcut line under them. Dragging Dimmela onto Applications copies it, and it opens without a Gatekeeper warning.
- [ ] After changing `scripts/dmg/background.py` or the icon positions: `python3 scripts/dmg/background.py`, then `scripts/dmg/make-dmg.sh --layout <Dimmela.app> /tmp/x.dmg` to save the window layout again.

### Coding agents as Provider profiles (v2 ticket 04)

Before every release, with each CLI installed and signed in (these CLIs update themselves):

- [ ] Settings › Post-processing › + › With your coding agent's plan: add Claude Code, Codex, GitHub Copilot, OpenCode and Pi. Each editor shows the CLI's path and version, and the model menu lists the plan's models (Claude Code's fixed list).
- [ ] *Test Connection* answers for each one, in a few seconds.
- [ ] A Dictation with each one in use is Post-processed; `~/Library/Logs/Dimmela/Dimmela.log` shows `LLM reply through <agent>` with `0 tool calls`.
- [ ] After an OpenCode Dictation, `opencode session list --standalone` run in `$TMPDIR/Dimmela-opencode-work` lists no session.
- [ ] Sign out of one (`codex logout`): its editor says it is not signed in; with another profile marked Fallback, a Dictation is answered by that one and the notification says so.
- [ ] With an agent in use, `Esc` during processing ends the run: no `codex`, `claude`, `copilot`, `opencode` or `pi` process is left (`pgrep -fl`).

### Built-in Modes (v2 ticket 07)

- [ ] First launch of this version: `~/.dimmela/modes` holds `clean.md`, `markdown.md`, `email.md`, `prompt.md`, `shorter.md` and `bullets.md`; Settings › Modes lists the folder as a Mode source and the six enabled after the Modes you had, in that order (Clean first), with the same digits as before.
- [ ] With no Default Mode, the welcome window offers *Start Every Dictation with Clean*.
- [ ] Markdown: "voglio scrivere una lista della spesa latte uova pane" pastes a list; "fai una tabella con nome e ruolo…" a table; "cose da fare come checklist…" `- [ ]` items; a plain sentence stays a sentence.
- [ ] Email: "ciao Marco ti scrivo per la riunione di giovedì, anzi no venerdì alle 10, fammi sapere" pastes a short email in Italian, with the greeting said and no invented sign-off; Friday, not Thursday.
- [ ] Prompt: "allora vorrei che aggiungessi un retry all'upload in source slash upload dot ts e poi non toccare i test" pastes imperative sentences with `src/upload.ts` in code and the instruction about the tests; the assistant's work is not done in the answer.
- [ ] Shorter: a long rambling Dictation comes back much shorter with every number, name and date.
- [ ] Bullets: three ideas dictated in a row come back as three "- " lines, in order, with no title.
- [ ] Edit `clean.md`, relaunch: the edit stays. Delete `markdown.md`, relaunch: it does not come back.



### Welcome tour

- [ ] First launch: the tour opens on "Just say it.", the green reaching the top of the window; the fn and space keys press themselves now and then (still with Reduce Motion).
- [ ] Setup: each card ticks itself as the permission is granted or the model is ready, also when coming back from System Settings.
- [ ] Try it: with everything allowed, hold fn+Space in the tour: the keys turn green with the level bars, and the text lands in the box. Return types a new line there instead of going on.
- [ ] Modes: the list shows the enabled Modes; *Start every Dictation with* sets the Default Mode.
- [ ] *Start Dictating* closes it; Settings › About offers *Welcome Tour…*; the menu does not.
- [ ] Dark mode: the hero is dark green with light text, every page readable.

