# Dimmela v2: feedback after v0.1.7

Status: needs-triage

## Problem Statement

After a few weeks of daily use:

- When the Provider fails (a 429, a 5xx, a timeout) the Dictation pastes the Transcript and the Post-processing is lost. There is no retry and no second Provider to fall back on.
- There is a single Provider. Takku now has named Provider profiles and can use the coding agents already signed in on the Mac (Claude Code, Codex, OpenCode, Pi, Copilot): Dimmela should offer the same.
- Getting the last Dictation back means opening the History submenu.
- A new user has no Modes until they write or clone prompt files.
- *Report a Problem…* is only in the menu bar menu, not in Settings.
- Only Parakeet v3 is available; Takku also offers Parakeet Ultra.

## Solution

Ported from Takku wherever Takku already solved it:

1. Post-processing retries transient failures (Takku's `ChatClient.retrying`), with waits short enough for a Dictation.
2. Provider profiles: several named Providers, one selected.
3. Fallback: when the selected profile still fails after its retries, the next profile in the user's order is tried before pasting the Transcript.
4. Coding agent CLIs as Providers, run with nothing of the user's setup (Takku ADR 0017).
5. *Copy Last Dictation* in the menu, and a way to Post-process the last Dictation again (only if retry and fallback leave a real need).
6. Built-in Modes: one that cleans the Transcript, one that turns it into Markdown (lists, tables) when the user says so.
7. An About tab in Settings with version, updates and *Report a Problem…*.
8. Transcription model choice: Parakeet v3 and Parakeet Ultra.
9. Last: an optional one-time payment instead of Takku-style credit.

## Open questions

- Retry waits: Takku waits 5 s and 20 s, which is too long while the user waits for a paste. Proposed 1 s and 3 s, `Retry-After` honoured only up to a few seconds.
- Whether an agent CLI is fast enough for a Dictation (a `claude -p` run takes seconds before the first token). To measure before shipping.
- Built-in Modes: read-only and bundled, or copied into a folder the user can edit?
- Parakeet Ultra against the memory target (under 450 MB with the model loaded).
- Payment: what it unlocks, if anything, and where it is sold.

## Domain

New term to add to `CONTEXT.md` when issue 02 lands: **Provider profile**, as in Takku. **Fallback** may deserve one too.
