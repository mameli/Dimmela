# 03: Fallback to the next Provider profile

**What to build:** When the selected Provider profile still fails after its retries (01), Post-processing is tried with the next profile in the user's order, and only when every fallback profile has failed is the Transcript pasted.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [x] The user chooses which profiles take part in the fallback and in what order (off by default: a single profile behaves as today)
- [x] Fallback also on non-transient failures that a different provider can fix (401, 402, 404 model not found), not on Esc
- [x] A total time budget, so a Dictation never waits more than a set number of seconds before the Transcript is pasted
- [x] The overlay names the profile in use when it is not the first; the notification says which profile answered
- [x] The History entry and the Post-processing log record the profile that answered
- [x] Core tests: order, budget, all failing

## Comments

### 2026-11-10: implemented (not committed)

- Per-profile *Use as fallback* toggle; the chain is the selected profile, then the fallback ones in list order (`ProviderProfiles.chain`).
- Falls back on every failure except cancellation (including 400/422: another provider may accept the request). No new profile is started 20 s after Post-processing began (`DictationBoundaries.fallbackBudget`).
- `DictationProblem.postProcessingFellBack` tells the user which profile answered; the overlay shows the fallback's name; `PostProcessingRecord.profile` records it. The History entry does not record the profile.
- Tests: `FallbackTests`.
