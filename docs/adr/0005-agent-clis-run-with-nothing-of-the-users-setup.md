# A coding agent's CLI as a Provider profile runs with no tools and nothing of the user's setup

A user who already pays for a coding agent's plan (ChatGPT through Codex, GitHub Copilot, Claude through Claude Code, a plan signed in through OpenCode or Pi) can have that agent Post-process their Dictations: Dimmela runs the user's own installed and signed-in CLI, one run per request, through the same Chat Completions client as every Provider. Dimmela holds no key and offers no sign-in. Retry, Fallback and the Post-processing log work as with any profile. Dimmela takes Takku's decision as it is (Takku's ADR 0017), with its code: `AgentCLI` and `AgentCLI.Runner` come from TakkuCore.

An agent is not a chat model: it has tools and the user's setup. A run therefore gets none of them: no shell, file reading or any other tool, no instructions (AGENTS.md and the like), settings, MCP servers, plugins, hooks or memories, no session kept, in an empty folder. A Dictation is often text the user is about to send to someone, and it can quote what others wrote: with tools, a sentence in it could make the agent run a command or read a file. The agent's own system prompt is replaced by Dimmela's where the CLI allows it, and the Mode's instructions follow in the input.

This is a rule, not a default: a CLI that cannot run this way is not offered, and there is no option to bring the user's setup back.

## Consequences

- A run gets no API key variables from Dimmela's environment (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, GitHub tokens and the like): a CLI that finds one bills per token instead of using the plan, without the user knowing.
- The flags are Takku's and are checked with a real run before every release (`docs/TESTING.md`): these CLIs update themselves. When a CLI changes under Dimmela, its error reaches the user as the CLI wrote it, and the Fallback profiles are tried.
- A Dictation waits for the run. Measured in November 2026 on a short Italian Dictation with a small model, from request to answer: Pi 1–2 s, OpenCode 2–3 s, Claude Code about 3 s, Copilot 3–7 s, Codex about 6 s. Each editor says so. A run has 30 seconds, as a remote request.
- OpenCode keeps its sign-in next to its sessions, so every run saves a session there: Dimmela deletes it after the run, and before each run any session of its own left by an earlier one cut short. Copilot's empty home gets only who is signed in (never the token); Pi reads its settings file, which sits next to its sign-in, and is always given the model and the thinking level. See Takku's ADR 0017 for why.
- Claude Code is offered although Anthropic's terms are not clear on it: they forbid third-party apps offering Claude.ai sign-in and automated access without an API key "except where we otherwise explicitly permit it", and `claude -p` with a plan is documented. Dimmela offers no sign-in and runs the user's own, unmodified CLI. The risk is to the user's account; if Anthropic forbids it explicitly, the profile goes.
