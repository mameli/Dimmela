# 13: Launch at login

**What to build:** A General settings section lets me enable launch at login, so Dimmela (with its model loaded at launch) is always ready. The model is never unloaded: the spike in ticket 01 showed that keeping it loaded costs 25–50 MB.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] Launch at login can be toggled from Settings › General, including the requires-approval state
- [x] After login Dimmela starts in the menu bar and loads the model without user action

## Comments

### 2026-10-13: done (commit 81fa5a6)

Verified by hand by the user. Ported Takku's `SMAppService` toggle, in Settings › General and in the welcome window. The release build in /Applications needs it turned on again: it registers the app at its own path.
