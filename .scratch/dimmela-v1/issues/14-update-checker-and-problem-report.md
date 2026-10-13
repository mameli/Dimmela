# 14: Update checker and problem report

**What to build:** The menu has "Check for updates" and "Report a problem", ported from Takku: Dimmela checks GitHub Releases daily and shows a menu item when a newer version exists, and the problem report collects recent logs into a pre-filled issue.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] A daily check against GitHub Releases shows an update menu item when a newer version exists
- [x] "Report a problem" collects recent logs and opens a pre-filled report
- [x] Version comparison is covered by core tests

## Comments

### 2026-10-13: done (commit 0f8c3f6)

- Verified by hand by the user.
- Ported from Takku: `AppVersion`, `ProblemReport`, `UpdateChecker`, `ProblemReporter` and the GitHub bug form.
- Post-processing is described by model and local/remote only.
