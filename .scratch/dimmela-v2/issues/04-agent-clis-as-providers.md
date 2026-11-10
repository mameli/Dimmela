# 04: Coding agent CLIs as Provider profiles

**What to build:** A Provider profile can be one of the coding agents installed and signed in on the Mac: Claude Code, Codex, OpenCode, Pi, GitHub Copilot. Port `AgentCLI` and `AgentCLIRunner` from TakkuCore with their rules (Takku ADR 0017): no tools, none of the user's setup, no session kept, no API key variables passed, the system prompt replaced by the Mode.

**Blocked by:** 02

**Status:** needs-triage

- [ ] Measure first: time from request to answer for a short Transcript with each CLI. A Dictation waits for it; if it is many seconds, say so in Settings or drop that CLI
- [ ] The CLI is found as Takku finds it (the user's login shell first, then the usual places) and Settings shows its path and version
- [ ] Model menu per agent, as in Takku's Profile editor
- [ ] Works as a fallback profile (03)
- [ ] Tests through a fake CLI, as in Takku (`FakeCLI.swift`)
- [ ] ADR in Dimmela that adopts Takku ADR 0017, including the Claude Code terms caveat; README section

## Comments
