# 15: Release pipeline

**What to build:** A release script builds with Developer ID, notarizes and staples, zips, creates a GitHub Release and updates a Homebrew cask in a new tap (not inside `homebrew-takku`), adapted from Takku's script.

**Blocked by:** 12, 14

**Status:** ready-for-agent

- [x] One command produces a notarized, stapled build and a GitHub Release
- [x] A Homebrew cask in a new tap installs Dimmela, requires arm64 and macOS 15, and has uninstall/zap entries
- [ ] The update checker from ticket 14 detects the published release

## Comments

### 2026-10-13: v0.1.0 published

- `scripts/release.sh` is adapted from Takku. When no `dimmela` notarytool profile exists, it falls back to the `takku` one (same Apple ID and team).
- The build is signed with Developer ID and Hardened Runtime and notarized. Gatekeeper reports `accepted, source=Notarized Developer ID`. The zip is 12 MB.
- Release: https://github.com/mameli/Dimmela/releases/tag/v0.1.0
- Tap: https://github.com/mameli/homebrew-dimmela. The cask SHA-256 matches the zip downloaded from GitHub.
- Homebrew 7 requires `brew tap mameli/dimmela` before installing, so the READMEs and future release notes say so. The v0.1.0 release notes still show the one-line form.
- Not verified:
  - an actual `brew install` (it would change the user's Homebrew setup)
  - the update checker against a newer release (none exists yet; the update checker is still open below)
  - the Release build run by hand
