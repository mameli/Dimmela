# 09: Choose the transcription model: Parakeet v3 or Parakeet Ultra

**What to build:** Settings › Transcription offers more than one speech model, as Takku does (`Takku/Transcription/TranscriptionModels.swift`): Parakeet v3 (today's) and Parakeet Ultra (FluidAudio `AsrModelVersion.ultra`), each downloaded on demand, deletable, one selected.

**Blocked by:** none

**Status:** ready-for-human

- [x] Measure Parakeet Ultra's memory with the model loaded and the latency on short Dictations; the spec's target is under 450 MB
- [x] Switching models unloads the old one; the old one's files can be deleted
- [x] Download size and a one-line note per model, as in Takku
- [x] Whisper is out of scope unless Ultra disappoints on short Italian Dictations (Takku notes it can switch language on short replies)

## Comments

### 2026-11-10: implemented (not committed)

- `SpeechModelChoice` (v3, Ultra) in `SpeechModel.swift`, chosen in Settings › Transcription and saved under `speechModel`; v3 stays the default. Each model has its own folder; switching unloads the old one, whose files can be deleted from the same section.
- `<unk>` (Ultra's unrecognised word) is dropped from the Transcript (`UnknownWords`, tested in `FillerTests`).
- Measured with the smoke test (Debug build, spike audio, M-series Mac):

  | | v3 | Ultra |
  |---|---|---|
  | First preparation | already done | 196 s (download + Neural Engine compile) |
  | 6 s of audio | 0.15 s, 53 MB | 0.09 s, 61 MB |
  | 55 s of audio | 0.36 s, 82 MB | 0.36 s, 83 MB |

  Same memory and speed, well under the 450 MB target. On these two clips the text is about the same (neither has the Vocabulary applied in the smoke test).
