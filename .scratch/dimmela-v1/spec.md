# Dimmela v1

Status: ready-for-agent

## Problem Statement

I dictate all day with Handy: I hold a shortcut, speak Italian, and the text lands in whatever app I'm using, often rewritten by an LLM with one of my prompts. Handy works, but it is built with Tauri and sits in my menu bar with a 922 MB memory footprint (measured with Parakeet loaded). That is far too much for a tool that is idle most of the time.

I also can't use my existing skills (the `SKILL.md` folders I already maintain, such as my X voice) for Post-processing. Choosing a prompt means opening Handy's settings and changing the single selected one, so in practice I always dictate with the same prompt even when another one would fit better.

## Solution

Dimmela is a native macOS menu-bar app for Apple Silicon. It does what I use Handy for, with a fraction of the memory:

- `fn+space` starts a Dictation. Holding the shortcut makes it a Hold; a short tap makes it a Lock, which keeps recording hands-free until the next tap. `Esc` cancels.
- Parakeet TDT v3 runs locally on the Neural Engine and turns the audio into a Transcript. Dimmela applies my Vocabulary, removes Fillers, and pastes the text into the frontmost app.
- `shift+fn+space` does the same, then runs Post-processing with my Default Mode.
- During any Dictation I can press `1`–`9` to pick a Mode for that Dictation only, or `0` for no Post-processing. A small overlay shows what I'm choosing.
- Modes come from folders I already have: my prompt files and my skills. I enable the ones I want and order them, and the order gives each one its digit.
- The last few Dictations stay in the History, from where I can copy them or Post-process them again with another Mode.

Memory targets are under 60 MB without the speech model loaded and under 450 MB with it loaded.

## User Stories

### Dictation

1. As a user, I want to hold `fn+space` and speak, so that the Dictation ends and is processed as soon as I release the keys (Hold).
2. As a user, I want a short tap of `fn+space` (under 300 ms) to start a Dictation that keeps recording without holding anything, so that I can dictate long texts hands-free (Lock).
3. As a user, I want the next tap of `fn+space` to end a Lock, so that I control when it stops.
4. As a user, I want recording to start the instant I press the shortcut, so that my first words are never cut off while Dimmela decides between Hold and Lock.
5. As a user, I want `Esc` to cancel the current Dictation, so that nothing is pasted when I change my mind.
6. As a user, I want a cancelled Dictation to leave no trace in the History, so that the History holds only text I actually wanted.
7. As a user, I want `Esc` to reach the frontmost app normally when no Dictation is in progress, so that Dimmela doesn't break `Esc` everywhere else.
8. As a user, I want a Dictation with no detected speech to paste nothing and make no LLM call, so that an accidental tap costs nothing.
9. As a user, I want the shortcuts fixed to `fn+space`, `shift+fn+space` and `Esc`, so that there is nothing to configure.
10. As a user, I want Dimmela to ignore a new Dictation shortcut while the previous Dictation is still being processed, so that two Dictations never race each other's paste.

### Transcription

11. As a user, I want my speech transcribed locally with Parakeet TDT v3, so that plain dictation works offline and costs nothing.
12. As a user, I want Italian and the occasional English term recognised without choosing a language, so that mixed speech just works.
13. As a user, I want the speech model kept loaded by default, so that every Dictation is fast.
14. As a user, I want an option to unload the model after a period of inactivity, so that I can trade the first Dictation's latency for memory.
15. As a user, I want leading and trailing silence trimmed by voice activity detection, so that pauses don't slow transcription or produce junk text.
16. As a user, I want Dimmela to record without voice processing, so that my AirPods don't switch to call mode when I dictate.
17. As a user, I want recording to keep working when I plug in or switch microphones, so that a device change doesn't silently break dictation.

### Text cleanup

18. As a user, I want my Vocabulary terms (e.g. "Claude", "Jira") enforced in the Transcript by replacing their known variants, so that names I use often are spelled right.
19. As a user, I want to add, edit and remove Vocabulary terms and their variants in the settings, so that I can fix recurring recognition errors.
20. As a user, I want Fillers ("ehm", "uhm", "mmh", a lone "eh") removed from the Transcript, so that plain dictation reads cleanly.
21. As a user, I want words with meaning such as "cioè" or "tipo" never removed automatically, so that cleanup doesn't change what I said.

### Output

22. As a user, I want the final text pasted into the frontmost app at the cursor, so that I don't have to switch windows.
23. As a user, I want my clipboard restored after the paste, so that dictating doesn't overwrite what I had copied.
24. As a user, I want a trailing space after the pasted text, so that consecutive Dictations don't run together.
25. As a user, I want Dimmela to tell me when it can't paste because Accessibility permission is missing, so that I know why nothing appeared.

### Post-processing and Modes

26. As a user, I want `shift+fn+space` to apply my Default Mode, so that my most common rewrite needs no extra key.
27. As a user, I want to press a digit `1`–`9` during a Dictation (Hold or Lock) to apply that Mode to this Dictation only, so that I can pick the right Mode while I speak.
28. As a user, I want `0` during a Dictation to mean "no Post-processing", so that I can skip the Default Mode after starting with `shift`.
29. As a user, I want the last digit I press during a Dictation to win, so that I can correct a wrong pick.
30. As a user, I want digits pressed during a Dictation not to reach the frontmost app, so that they don't end up in my document.
31. As a user, I want digits to behave normally when no Dictation is in progress, so that Dimmela doesn't interfere with typing.
32. As a user, I want to choose the Default Mode from the menu-bar menu, so that I can change it without opening the settings.
33. As a user, I want to add folders as Mode sources (e.g. `~/.claude/skills` and my `handy-config` folder), so that Dimmela finds the prompts and skills I already maintain.
34. As a user, I want Dimmela to list every skill (`SKILL.md` folder) and every prompt file it finds in my Mode sources, so that I can see what's available.
35. As a user, I want to enable only the skills and prompt files that make sense for dictation, so that coding skills like `tdd` never show up as Modes.
36. As a user, I want to reorder enabled Modes, so that the ones I use most get the lowest digits.
37. As a user, I want each Mode shown with a readable name (the skill's `name` or the prompt file's name), so that I recognise it in the overlay and menu.
38. As a user, I want a skill used as a Mode to send its `SKILL.md` (without frontmatter) and every Markdown file in its `references/` folder, so that skills that depend on references keep working.
39. As a user, I want skills wrapped in a short fixed Dimmela preamble that says to apply the instructions to the Transcript and return only the final text, so that skills written for an agent behave as Post-processing.
40. As a user, I want prompt files sent as they are, so that the prompts I already wrote as system prompts are not altered.
41. As a user, I want Modes read from disk at every Dictation, so that an edit to a skill or prompt applies to the next Dictation without restarting.
42. As a user, I want my Vocabulary terms included in every Post-processing request, so that the LLM fixes the terms that substitution missed.
43. As a user, I want to configure an OpenAI-compatible provider (base URL, model, API key), so that I can use OpenRouter with Claude Haiku or my own local server.
44. As a user, I want the API key stored in the Keychain, so that it's not sitting in a preferences file.
45. As a user, I want to test the provider connection from the settings, so that I know Post-processing works before I rely on it.
46. As a user, I want the Transcript pasted and a notification shown when Post-processing fails (offline, timeout, API error, missing Mode file), so that I never lose what I dictated.

### Overlay

47. As a user, I want a small pill at the bottom of the screen while I'm recording, so that I know Dimmela is listening.
48. As a user, I want the pill to show the microphone level, so that I can see my voice is being picked up.
49. As a user, I want the pill to show the current Mode (or that there is none), so that I know what will happen to my text.
50. As a user, I want the numbered list of Modes to appear above the pill when I press a digit or hold `shift` during a Dictation, so that I can see the digits only when I need them.
51. As a user, I want the pill to show that Dimmela is processing after the recording ends, so that I know to wait for the paste.
52. As a user, I want the overlay never to take focus from the app I'm typing in, so that the paste lands in the right place.

### History

53. As a user, I want my last 5 Dictations kept with their audio, Transcript, final text, Mode and time, so that I can recover something I dictated.
54. As a user, I want to copy any History entry's final text or Transcript from the menu bar, so that I can paste it again elsewhere.
55. As a user, I want to Post-process a History entry again with another Mode, so that I can fix a wrong Mode pick without dictating again.
56. As a user, I want older entries and their audio deleted as new ones arrive, so that the History never grows.

### Menu bar, settings and onboarding

57. As a user, I want Dimmela to live only in the menu bar, with no Dock icon, so that it stays out of the way.
58. As a user, I want the menu-bar icon to show idle, recording and processing states, so that I see what's happening at a glance.
59. As a user, I want a settings window with sections for General, Transcription, Post-processing, Modes and Vocabulary, so that every option has one obvious place.
60. As a user, I want to enable launch at login, so that Dimmela is always ready.
61. As a user, I want a first-run window that asks for microphone and Accessibility permissions and links to the right System Settings pane, so that setup is guided.
62. As a user, I want the first-run window to download Parakeet and prepare it for the Neural Engine with visible progress, so that the one-time multi-minute compile happens before my first Dictation.
63. As a user, I want to see the model's state (not downloaded, downloading, preparing, ready) and delete or re-download it from the settings, so that I can recover from a broken download.
64. As a user, I want Dimmela to tell me when a new version is available, so that I can update.
65. As a user, I want to report a problem with recent logs attached, so that bugs are easy to diagnose.

### Footprint

66. As a user, I want Dimmela to use under 60 MB with the model unloaded and under 450 MB with Parakeet loaded, so that it is genuinely lighter than Handy.
67. As a user, I want Dimmela to use no CPU while idle, so that it doesn't affect my battery.

## Implementation Decisions

### Platform and project

- **Platform:** native Swift 6 (strict concurrency) and SwiftUI, with AppKit where SwiftUI can't do the job. Apple Silicon only, macOS 15 or later.
- **Identity:** bundle id `app.dimmela.Dimmela`. The app is an `LSUIElement` (no Dock icon), with no sandbox and Hardened Runtime in Release builds.
- **Local signing:** builds are signed with a self-signed local certificate, as in Takku, so that TCC grants survive rebuilds.
- **Code split:** there are two parts, as in Takku:
  - a dependency-free Swift package, `DimmelaCore`, that holds all domain logic and is unit-tested;
  - the app target, which holds everything platform-bound.
- **Reuse from Takku:** code is copied and renamed, not shared through a common package. The two apps can then diverge freely, and a shared package can be extracted later if the duplication starts to hurt. The parts to copy:
  - Keychain helper
  - OpenAI-compatible chat client with its closure-based transport
  - provider profile validation (https except loopback)
  - Parakeet model download and the transcriber actor
  - launch-at-login toggle
  - update checker
  - problem reporter
  - release script, CI workflow and xcconfig signing setup
- **Speech:** FluidAudio runs Parakeet TDT v3 on CoreML and the Neural Engine. No other engine ships in v1.

### DimmelaCore modules

**Dictation controller.** This is the single deep module and the only test seam. It is a state machine that owns the whole Dictation lifecycle.
- **States:** idle → recording → processing → idle. A Dictation can be cancelled from recording or from processing.
- **Inputs:** abstract events with timestamps:
  - shortcut down, with a flag saying whether `shift` was held
  - shortcut up
  - Mode digit (0–9)
  - `Esc`
  - microphone level updates
  - the recorded samples when recording stops
- **Injected boundaries,** as closures:
  - `transcribe(samples) async throws -> String`
  - the chat transport used by the chat client
  - `paste(text)`
  - `notify(message)`
  - `now()`
  - a Mode-content loader (by default backed by the Mode catalog)
- **Hold/Lock rule:**
  - Recording starts on shortcut down.
  - A shortcut up that comes 300 ms or more after the down ends a Hold and starts processing.
  - A shortcut up that comes sooner turns the Dictation into a Lock. The next shortcut down ends the Lock.
- **Mode rule:**
  - Starting with `shift` selects the Default Mode.
  - Starting without `shift` selects no Mode.
  - Every digit during recording overrides the selection: `0` means none, `1`–`9` mean the enabled Mode at that position, and the last digit wins.
  - A digit that maps to no enabled Mode is ignored.
- **Processing pipeline:**
  1. If the trimmed audio contains no speech, the Dictation ends with nothing pasted.
  2. Otherwise the samples are transcribed.
  3. Vocabulary substitution is applied, then Filler removal.
  4. An empty Transcript ends the Dictation with nothing pasted.
  5. With a Mode selected, Post-processing runs. On any failure the controller falls back to the Transcript and notifies.
  6. A trailing space is appended and the text is pasted.
  7. A History entry is written.
- **Published state for the overlay:**
  - phase
  - microphone level
  - current Mode name or none
  - whether the Mode list is visible (after a digit or while `shift` is held)
- **Event interception:** the controller tells the platform layer whether digits and `Esc` should be swallowed. That is true only while a Dictation is in progress.
- **Concurrency:** while processing, a new shortcut down is ignored.

**Mode catalog.**
- **Scanning:** it scans the configured Mode source folders.
  - A skill is any subfolder containing a `SKILL.md`. Its name comes from the frontmatter `name`, falling back to the folder name.
  - A prompt file is any top-level `.md` file that isn't a README. Its name comes from the file name.
- **Enabled Modes:** the list is ordered and stored as stable identifiers (source folder plus relative path). The first nine enabled Modes get digits 1–9, in order.
- **Content assembly**, done at every Dictation:
  - A skill becomes the fixed Dimmela preamble, then the `SKILL.md` body without frontmatter, then each `references/*.md` file in name order.
  - A prompt file is used verbatim.
  - In both cases a line listing the Vocabulary terms is appended.
  - A Mode whose files are gone fails the Post-processing (which falls back to the Transcript), and the Mode is flagged as missing in the settings.

**Post-processing request.** The system message is the assembled Mode content and the user message is the Transcript. The request is a single non-streaming chat completion with a bounded timeout, and only the final text is used.

**Vocabulary.**
- Terms with known variants are replaced deterministically, case-insensitively and on word boundaries, as in Takku.
- No biasing is passed to the speech engine (ADR 0003).

**Fillers.** Fillers are removed deterministically from a fixed list of purely vocal sounds, with whitespace and punctuation tidied afterwards.

**History.**
- **Contents:** the last 5 Dictations. Each entry stores the audio (16 kHz mono), Transcript, final text, Mode identifier and name, and timestamp.
- **Storage:** entries live as files in the app's Application Support folder. The oldest entry and its audio are deleted when a sixth arrives.
- **Exclusions:** cancelled Dictations are never stored.
- **"Post-process again with…":** it re-runs Post-processing on the stored Transcript with the chosen Mode, copies the result to the clipboard and notifies. The menu has just taken focus, so pasting is not reliable here.

### App-target modules

- **Shortcut monitor:**
  - It uses a CGEventTap and reads the `fn` key through the secondary-fn modifier flag.
  - It emits shortcut down/up (with `shift`), digits and `Esc` to the controller, and swallows digits and `Esc` only while the controller says a Dictation is in progress.
  - It requires Accessibility, which paste needs anyway.
  - It re-enables the tap if the system disables it.
- **Microphone recorder:**
  - It uses AVAudioEngine with voice processing off and converts to 16 kHz mono Float32 in memory.
  - It publishes the microphone level.
  - It recovers from device changes using Takku's approach.
- **Voice activity detection:** FluidAudio's Silero VAD trims leading and trailing silence and reports "no speech".
- **Transcriber:**
  - It is an actor that keeps Parakeet loaded and serialises requests.
  - It can optionally unload after a configurable idle time, reloading on the next Dictation.
  - It exposes the model state: not downloaded, downloading, preparing, ready.
- **Paster:**
  - It saves the pasteboard, writes the text, posts `⌘V` through CGEvent, and restores the pasteboard after a short delay.
  - It reports an error when Accessibility is not granted.
- **Overlay:**
  - It is a non-activating, borderless floating panel at the bottom centre of the active screen that never takes key focus.
  - It renders the pill (level, Mode name, processing indicator) and the numbered Mode list from the controller's published state.
- **Menu bar:**
  - The state icon shows idle, recording and processing.
  - The menu has a Default Mode picker, a History submenu (copy final text, copy Transcript, "Post-process again with…"), Settings, Check for updates, Report a problem, and Quit.
- **Settings window:**
  - **General:** launch at login, model unload timeout.
  - **Transcription:** model state, download, delete.
  - **Post-processing:** base URL, model, API key in Keychain, connection test.
  - **Modes:** Mode sources, discovered skills and prompt files, enable, reorder, Default Mode.
  - **Vocabulary:** terms and variants.
- **Onboarding window:**
  - It asks for microphone and Accessibility permission and deep-links to System Settings.
  - It downloads and prepares the model with progress, using the "bring back to front" trick from Takku.
- **Persistence:**
  - Settings go in UserDefaults, with shared keys for `@AppStorage`.
  - The API key goes in the Keychain.
  - The model and History go in Application Support under `Dimmela`.

## Testing Decisions

- **What a good test is:** a good test drives Dimmela the way the user does and checks what the user would see. It sends shortcut, digit and `Esc` events plus samples into the Dictation controller, then asserts on:
  - what was pasted
  - what the overlay state said
  - what landed in the History
  - what was notified
  - what request reached the chat transport

  Tests never assert on internal states or private helpers.
- **One seam:** almost everything is tested through the Dictation controller. Fakes are injected only at its boundaries:
  - a fake `transcribe` returning canned text
  - a stub chat transport (like Takku's stub transport) that records requests and returns canned answers or errors
  - a recording `paste`
  - a controllable clock for the 300 ms Hold/Lock threshold
- **Behaviours covered through the controller:**
  - Hold vs Lock
  - `Esc` in each phase
  - `shift` and the Default Mode
  - digits (including `0`, last-wins, and unmapped digits)
  - no speech and empty Transcript
  - Vocabulary substitution
  - Filler removal (including "cioè" untouched)
  - trailing space
  - the full Post-processing request (preamble, `SKILL.md` without frontmatter, `references/`, Vocabulary line, prompt files verbatim)
  - fallback to the Transcript on failure
  - History rotation at 5 entries
  - cancelled Dictations not stored
  - "Post-process again with…"
  - the swallow/pass-through decision for digits and `Esc`
- **Mode sources:** these are tested with real temporary folders on disk (skills with and without `references/`, prompt files, READMEs, missing files). There is no filesystem seam.
- **Framework:** Swift Testing in `DimmelaCore`, written test-first. The prior art is TakkuCore's test suite and its stub transport.
- **Platform code** is not unit tested: event tap, audio, FluidAudio, pasteboard, overlay, menu bar and settings. It is verified with:
  - DEBUG-only launch-argument smoke tests, as in Takku (e.g. transcribe a bundled audio file, run a Dictation against a fake provider)
  - a manual test checklist kept in the repo
- **Memory:** it is measured manually with `footprint`, idle with and without the model loaded, and compared with the targets. The first measurement comes from the spike, before the rest is built.
- **CI:** the setup is adapted from Takku: `swift test` for the core, plus an unsigned Debug build of the app.

## Out of Scope

- **Shortcuts:** a shortcut recorder or any configurable shortcuts. They are fixed, now and later.
- **Speech:** streaming or live transcription models, any speech engine other than Parakeet TDT v3, and a language setting (Parakeet detects the language on its own).
- **Providers:** any other provider adapter (Apple Intelligence, native Anthropic API, and so on) beyond a single OpenAI-compatible one.
- **Mode selection:** letting the LLM pick the Mode from what was said.
- **How skills run:** running a skill's scripts, or running skills through an agent such as `claude -p` (ADR 0002).
- **Context:** sending the frontmost app's name or the selected text as context.
- **Streaming output:** streaming Post-processing output into the frontmost app.
- **Feedback:** start/stop sounds.
- **Platforms and distribution:** Intel Macs, macOS 14 or earlier, App Store distribution and sandboxing.
- **Shared code:** a package shared with Takku.

## Further Notes

**Build order.** Each step produces something usable:
1. A spike that loads Parakeet with FluidAudio in a minimal app and measures memory against the targets. This step decides whether the project keeps its promise.
2. A minimal Dictation: menu bar, `fn+space` Hold, Transcript pasted.
3. Lock and `Esc`.
4. Post-processing, Mode sources, Default Mode, `shift+fn+space`.
5. Overlay and Mode digits.
6. History.
7. Vocabulary and Fillers.
8. Onboarding and settings polish.
9. Release pipeline (Developer ID, notarization, GitHub Releases, Homebrew cask in a new tap, not inside `homebrew-takku`).

**Baseline.** Handy 0.9.7 with Parakeet loaded had a 922 MB footprint on 2026-10-12.

**Reading.** The glossary is in `CONTEXT.md`. The ADRs are 0001 (native Swift), 0002 (skills as system prompts) and 0003 (Vocabulary by substitution). Takku's ADR 0005 holds the evidence against engine biasing for Italian.

**Defaults chosen here, not discussed explicitly.** These are cheap to change:
- `Esc` also cancels during processing.
- "Post-process again with…" copies instead of pasting.
- Only the first nine enabled Modes get digits.
- A new shortcut is ignored while a Dictation is processing.
