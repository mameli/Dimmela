# 04: Coding agent CLIs as Provider profiles

**What to build:** A Provider profile can be one of the coding agents installed and signed in on the Mac: Claude Code, Codex, OpenCode, Pi, GitHub Copilot. Port `AgentCLI` and `AgentCLIRunner` from TakkuCore with their rules (Takku ADR 0017): no tools, none of the user's setup, no session kept, no API key variables passed, the system prompt replaced by the Mode.

**Blocked by:** 02

**Status:** ready-for-human

- [x] Measure first: time from request to answer for a short Transcript with each CLI. A Dictation waits for it; if it is many seconds, say so in Settings or drop that CLI
- [x] The CLI is found as Takku finds it (the user's login shell first, then the usual places) and Settings shows its path and version
- [x] Model menu per agent, as in Takku's Profile editor
- [x] Works as a fallback profile (03)
- [x] Tests through a fake CLI, as in Takku (`FakeCLI.swift`)
- [x] ADR in Dimmela that adopts Takku ADR 0017, including the Claude Code terms caveat; README section

## Comments

### 2026-11-11: measured, implemented (not committed)

Time from request to answer, Takku's flags, a short Italian Dictation (Clean prompt from `dimmela-config/prompt.md`), two runs each:

| CLI | Model | Run 1 | Run 2 |
|---|---|---|---|
| Pi 1.5.0 | github-copilot/claude-haiku-5.5, thinking off | 1.2 s | 1.4 s |
| OpenCode 2.2.6 | openrouter/~anthropic/claude-haiku-latest | 2.9 s | 2.2 s |
| Claude Code 2.1.321 | claude-haiku-5-5, thinking off | 2.9 s | 3.0 s |
| Copilot 1.0.105 | claude-haiku-5.5 | 7.3 s | 3.0 s |
| Codex 0.166.0 | gpt-5.6-luna, low | 5.5 s | 6.0 s |

None is slow enough to drop; each editor says how long a Dictation waits. Through Dimmela's runner (real CLIs, once each): Pi 2.1 s, Claude Code 3.2 s, OpenCode 2.7 s, its session deleted.

- `AgentCLI` and `AgentCLI.Runner` ported from TakkuCore: Dimmela's system prompt, `dimmela` OpenCode agent and session title, `Dimmela-` scratch folders, 30-second run limit.
- Settings › Post-processing: + offers the agents not added yet; the editor shows what it does with the Transcript and how long it takes, the model menu, the reasoning levels the model accepts, the CLI's path and version or what is missing.
- Report a Problem names the agent, not "remote".
- Tests: Takku's FakeCLI suites (minus the Summary log ones), plus an agent profile that falls back to the next profile.
- ADR 0005, README, CONTEXT, `docs/TESTING.md` checklist.

To do by hand: the TESTING checklist with each CLI in the app (Settings, Dictation, Esc).
