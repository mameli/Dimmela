# Dimmela

Personal macOS menu-bar app for dictation: speak, Dimmela transcribes locally and pastes the text into the app you are using, optionally rewritten by an LLM. A native, lightweight alternative to Handy.

## Language

### Dictation

**Dictation** (`Dictation`):
One cycle from the start of recording to the text pasted in the frontmost app. Everything else revolves around it.
_Avoid_: recording, session, take

**Hold** (`Hold`):
A Dictation that lasts as long as the shortcut is held down and ends on release.
_Avoid_: push-to-talk (in code), PTT

**Lock** (`Lock`):
A Dictation started with a short tap of the shortcut: it keeps recording hands-free until the next tap.
_Avoid_: toggle, hands-free mode

### Text

**Transcript** (`Transcript`):
The raw text that the local speech model produces from a Dictation, before any Post-processing.
_Avoid_: transcription (for the text), raw text

**Post-processing** (`PostProcessing`):
The optional step that sends the Transcript to an LLM together with a Mode and replaces it with the LLM's answer.
_Avoid_: AI processing, rewrite, enhancement

**Mode** (`Mode`):
A named set of instructions for Post-processing. Its source is either a prompt file or a skill (`SKILL.md`): for Dimmela the two are the same thing.
_Avoid_: prompt, skill, template, preset (when talking about the concept)

**Mode source** (`ModeSource`):
A folder the user points Dimmela at, where it looks for skills and prompt files that can become Modes. Only the ones the user enables become Modes.
_Avoid_: library, skills folder

**Default Mode** (`defaultMode`):
The Mode every Dictation starts with, unless the user picks another during it. It can be none: the Dictation then gives the Transcript alone.
_Avoid_: active mode, selected prompt

**Mode digit**:
The position 1–9 of an enabled Mode, which the user presses during a Dictation to apply that Mode; 0 means no Post-processing.
_Avoid_: slot, hotkey number

**Mode list** (`isModeListVisible`):
The numbered list of the Mode digits shown during a Dictation: `shift` opens and closes it, the arrows move through it, a digit or `Return` closes it.
_Avoid_: picker, selector, menu

**Filler**:
A purely vocal sound with no meaning ("ehm", "uhm", "mmh") that Dimmela removes from the Transcript. Words with meaning ("cioè", "tipo") are never Fillers.
_Avoid_: filler word (for words with meaning)

### History

**History** (`History`):
The last Dictations kept by Dimmela, each with its audio, Transcript, final text and Mode, so they can be copied or Post-processed again with another Mode.
_Avoid_: log, archive

**Vocabulary** (`Vocabulary`):
The user's custom words (e.g. "Claude", "Jira") that Dimmela enforces in the Transcript.
_Avoid_: custom words, dictionary
