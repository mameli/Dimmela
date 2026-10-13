# 04: Post-processing with a prompt-file Mode

**What to build:** I can configure an OpenAI-compatible provider (base URL, model, API key stored in the Keychain) and test the connection. I can add a Mode source folder (e.g. my `handy-config`), see its prompt files, enable and order them, and choose the Default Mode from the menu-bar menu. `shift+fn+space` dictates and Post-processes the Transcript with the Default Mode; the prompt file is sent verbatim as the system message and re-read at every Dictation. If Post-processing fails (offline, timeout, API error, missing file) the Transcript is pasted and a notification explains why.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] Settings has a Post-processing section with base URL, model, API key (Keychain) and a working connection test
- [x] Settings has a Modes section to add/remove Mode sources and enable/reorder the prompt files found (READMEs excluded)
- [x] The menu-bar menu has a Default Mode picker
- [x] `shift+fn+space` pastes the LLM's answer; plain `fn+space` still pastes only the Transcript
- [x] Editing the prompt file takes effect on the next Dictation without restarting
- [x] On any Post-processing failure the Transcript is pasted and a notification is shown
- [x] Controller tests with a stub chat transport cover request shape (system = prompt verbatim, user = Transcript), Default Mode selection and fallback on failure
- [x] Mode catalog tests use real temporary folders

## Comments

### 2026-10-13: done (commit 60d6d5b)

- Verified by hand by the user with OpenRouter and the handy-config prompts.
- Handy's `${output}` placeholder is dropped and the Transcript is sent as the user message, as Handy does with OpenRouter.
- The provider timeout was briefly 5 s at the user's request, then restored to 30 s (60 s total) in ticket 05: long skills risk exceeding 5 s.
- Reasoning is not explicitly disabled; Haiku does not reason by default.
