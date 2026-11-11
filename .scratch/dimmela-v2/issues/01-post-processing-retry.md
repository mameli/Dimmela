# 01: Retry transient Post-processing failures

**What to build:** A Post-processing request that fails for a reason that can pass by itself is sent again before Dimmela gives up and pastes the Transcript. Port `ChatClient.retrying(after:)` from TakkuCore (`TakkuCore/Sources/TakkuCore/ChatClient.swift`, tests in `ChatClientRetryTests.swift`).

**Blocked by:** none

**Status:** ready-for-human

- [x] Retried: network errors and timeouts, HTTP 408, 429, 5xx. Not retried: 400, 401, 403, 404, 422, empty or truncated reply
- [x] Waits short enough for a Dictation (proposed 1 s, then 3 s); `Retry-After` honoured only when it is within that budget
- [x] Esc during a retry cancels the Dictation as it does now
- [x] The overlay shows that Dimmela is retrying
- [x] Every attempt, failed ones too, goes to the Post-processing log and the app log
- [x] Core tests with a fake transport: which failures retry, how many times, cancellation

## Comments

### 2026-11-10: implemented (not committed)

- `ChatClient.retrying(after:sleep:)` ported from Takku; waits 1 s then 3 s, `Retry-After` up to 5 s (`ChatClient.longestRetryWait`).
- `DictationController.retries` drives the overlay ("Clean · retrying…"); `PostProcessingRecord.attempts` counts the requests.
- Test Connection still sends once. Post-processing again retries too, without touching the overlay.
- Tests: `ChatClientRetryTests`, new cases in `PostProcessingTests`.
