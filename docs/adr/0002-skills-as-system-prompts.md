# Skills become Modes as system prompts, not as agent runs

A skill used as a Mode is read from disk at every Dictation: its `SKILL.md` without frontmatter plus every `.md` file in its `references/` folder, wrapped in a short fixed Dimmela preamble ("you are the final stage of a dictation pipeline; apply these instructions to the Transcript; return only the final text"), and sent as the system prompt of a single OpenAI-compatible chat request. Prompt files are sent as they are. Scripts and other files in a skill are ignored.

Running the skill through an agent (`claude -p` or similar) was rejected: it takes seconds just to start, which is unacceptable between the end of speech and the paste, and dictation never needs tools. Letting the LLM pick the skill from what the user said was rejected too: it adds a routing call and can pick the wrong one, while a Mode digit pressed during the Dictation is instant and explicit.
