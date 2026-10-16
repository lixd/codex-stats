# Turn Performance Contract

## 1. Scope / Trigger

Read before changing lifecycle timing, attaching performance to usage rows or displaying a token rate. [Token Accounting](token-accounting.md) remains independent: missing timing never changes accepted expenditure.

## 2. Signatures

`UsageRecord.turnPerformance: TurnPerformance?` contains `durationMilliseconds`, optional `firstTokenMilliseconds`, and optional complete `outputTokens` / `responseCount`. `averageOutputTokensPerSecond` is full Turn output divided by explicit duration in seconds. Core and the offline report share this metadata; App does not infer timers.

## 3. Contracts

- Lifecycle events contain a Turn ID but no owner field. Pair `task_started` / `task_complete` within a file with recorded session metadata, and require a matching native response with explicit owner / Turn inside that interval; do not infer membership from `turn_context`. Duration comes from unsigned, positive, Int64-safe `duration_ms`, not subtraction of event timestamps. TTFT is optional, unsigned and no greater than duration; recorded zero is known, absence is unknown.
- Aborted, failed or contradictory lifecycle evidence invalidates timing. Exact repeated completions do not multiply timing or output.
- Only accepted native response rows with explicit owner / Turn may receive performance. Legacy cumulative rows have no request timer.
- Mean output rate requires complete response-set coverage: valid start/end interval, owned native responses, no conflicting identity, incomplete/invalid history or unpaired cumulative usage. Coverage is proved from all copies and accepted rows, not the currently visible subset. Incomplete candidate intervals and native responses without an explicit Turn inside the same time interval in any copy deny output coverage, even if a different copy has a valid complete timer. An unassigned native response with missing time also denies coverage because its interval cannot be proved. Cumulative frames from every physical copy in the Turn / interval (or with missing time) must be paired to native notifications; conservative accounting exclusion alone is not proof of complete performance coverage.
- Duration and TTFT may be known while output coverage is unknown; then output/count/rate remain nil. Never label missing rate as zero.
- A Turn may include multiple responses, tools and waiting. Its average is not per-request latency or pure generation speed. Date/model/search filtering must not truncate its output numerator.

### Operation-local indexes

`attachTurnPerformance` groups recorded-session copies and accepted row indices by Turn once. Build native ownership/membership, failed Turns, unpaired-counter Turn/frame-position/time evidence and unassigned-native timestamps from **all** physical copies. Pair counters with `inherited: 0`; accounting's inherited-prefix cutoff cannot replace coverage evidence. Counter relevance is frame range OR Turn ID OR inclusive time interval OR missing timestamp. Sorted interval lookup may answer existence, but cannot drop any OR branch. Keep indexes local to the scan and measure retained-memory cost; no persistent cache is required.

## 4. Validation / Error Matrix

| Evidence | Result |
|---|---|
| Complete owned multi-response Turn | Full duration/TTFT and deduplicated output/count/rate |
| No completion, abort, error, conflicting timers | No performance |
| Valid timer but uncertain response coverage | Timer only, no output rate |
| Missing TTFT / recorded zero | Unknown / zero respectively |
| Legacy/cumulative row or foreign owner | No inferred request performance |
| Cross-day filter selects one response | Same full Turn numerator as unfiltered report |

## 5. Good / Base / Bad Cases

Good: show “complete Turn, includes tools and waiting” with explicit 120000 ms and 3600 fully covered output tokens, giving 30 tok/s. Base: request measured timers remain unavailable; separately marked request estimates follow [Request Estimates](request-estimates.md). Bad: divide one response's output by the interval to an adjacent response or use a Turn timer as one request's generation time.

## 6. Required Tests

Run `./Scripts/test.sh`, covering complete multi-response, deduplication, cross-day/model filtering, missing/invalid lifecycle, zero/missing TTFT, conflicting or aborted completions, foreign owner, physical copies and incomplete coverage. Native preview/action checks verify presentation separately; static images do not establish user installation or macOS 14 interaction.

## 7. Wrong vs Correct

Wrong: recompute rate from filtered request rows or clamp an implausible estimated rate.

Correct: attach the coverage-verified, full Turn value once in Core; display request estimates separately when boundary evidence is available, and explain Turn scope explicitly.
