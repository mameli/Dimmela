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
