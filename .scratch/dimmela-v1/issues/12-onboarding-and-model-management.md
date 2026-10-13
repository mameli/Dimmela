# 12: Onboarding and model management

**What to build:** On first run a window guides me through microphone and Accessibility permissions (with links to the right System Settings panes, coming back to the front after each prompt as in Takku) and downloads and prepares Parakeet with visible progress, so the one-time Neural Engine compile happens before my first Dictation. The Transcription settings section shows the model state (not downloaded, downloading, preparing, ready) and lets me delete or re-download it.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] First run opens an onboarding window that requests microphone and Accessibility permission and reflects their status
- [x] The onboarding window downloads and prepares the model with progress and states when it is ready
- [x] A half-finished download is detected and restarted rather than used
- [x] Settings › Transcription shows the model state and offers delete and re-download
- [x] Manual checklist covers a clean first run

## Comments

### 2026-10-13: done (commits d3b5a67, 6c4107c)

- The real model download was exercised by moving the seeded model aside: download and Neural Engine preparation took 62 s on an M3 Pro, then transcription worked.
- The welcome window was checked by the user with permissions already granted. The full first launch from zero (permissions reset with `tccutil`) was not run; the commands are in `docs/TESTING.md`.
- Notifications were added as a step (not in the ticket) after the user lost time with them turned off.
- The app icon in the window showed macOS 26's placeholder until Dimmela was registered again with `lsregister -f`: an icon cache issue of the Debug build path, not of the project.
