# 15: Release pipeline

**What to build:** A release script builds with Developer ID, notarizes and staples, zips, creates a GitHub Release and updates a Homebrew cask in a new tap (not inside `homebrew-takku`), adapted from Takku's script.

**Blocked by:** 12, 14

**Status:** ready-for-agent

- [ ] One command produces a notarized, stapled build and a GitHub Release
- [ ] A Homebrew cask in a new tap installs Dimmela, requires arm64 and macOS 15, and has uninstall/zap entries
- [ ] The update checker from ticket 14 detects the published release
