# 13: Launch at login and model unload after inactivity

**What to build:** A General settings section lets me enable launch at login and choose whether the model stays loaded (default) or is unloaded after a period of inactivity. When unloaded, the next Dictation reloads the model automatically.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Launch at login can be toggled, including the requires-approval state
- [ ] Model unload timeout can be set to never (default) or a duration
- [ ] After the timeout the model is unloaded and footprint drops accordingly
- [ ] The next Dictation after an unload reloads the model and still pastes the Transcript
