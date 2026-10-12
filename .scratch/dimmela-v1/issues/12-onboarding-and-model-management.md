# 12: Onboarding and model management

**What to build:** On first run a window guides me through microphone and Accessibility permissions (with links to the right System Settings panes, coming back to the front after each prompt as in Takku) and downloads and prepares Parakeet with visible progress, so the one-time Neural Engine compile happens before my first Dictation. The Transcription settings section shows the model state (not downloaded, downloading, preparing, ready) and lets me delete or re-download it.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] First run opens an onboarding window that requests microphone and Accessibility permission and reflects their status
- [ ] The onboarding window downloads and prepares the model with progress and states when it is ready
- [ ] A half-finished download is detected and restarted rather than used
- [ ] Settings › Transcription shows the model state and offers delete and re-download
- [ ] Manual checklist covers a clean first run
