# 04: Post-processing with a prompt-file Mode

**What to build:** I can configure an OpenAI-compatible provider (base URL, model, API key stored in the Keychain) and test the connection. I can add a Mode source folder (e.g. my `handy-config`), see its prompt files, enable and order them, and choose the Default Mode from the menu-bar menu. `shift+fn+space` dictates and Post-processes the Transcript with the Default Mode; the prompt file is sent verbatim as the system message and re-read at every Dictation. If Post-processing fails (offline, timeout, API error, missing file) the Transcript is pasted and a notification explains why.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Settings has a Post-processing section with base URL, model, API key (Keychain) and a working connection test
- [ ] Settings has a Modes section to add/remove Mode sources and enable/reorder the prompt files found (READMEs excluded)
- [ ] The menu-bar menu has a Default Mode picker
- [ ] `shift+fn+space` pastes the LLM's answer; plain `fn+space` still pastes only the Transcript
- [ ] Editing the prompt file takes effect on the next Dictation without restarting
- [ ] On any Post-processing failure the Transcript is pasted and a notification is shown
- [ ] Controller tests with a stub chat transport cover request shape (system = prompt verbatim, user = Transcript), Default Mode selection and fallback on failure
- [ ] Mode catalog tests use real temporary folders
