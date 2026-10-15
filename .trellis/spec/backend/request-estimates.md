# Request Estimates

## 1. Scope / Trigger

Read before request-boundary parsing or displaying estimated request performance. [Accounting](token-accounting.md) remains authoritative; missing timing never drops expenditure. [Turn Performance](turn-performance.md) is a distinct measured whole-Turn contract.

## 2. Signatures

`UsageRecord.requestEstimate: RequestEstimate?` carries `startedAt`, `completedAt`, `durationMilliseconds`, `outputTokens`, optional computed `outputTokensPerSecond`. Core owns association and eligibility; App formats ≈ only. No body text is retained.

## 3. Contracts

- Boundary is a valid user/developer/system message, turn context/start, or tool output timestamp. First reasoning/assistant/tool-call output locks the preceding boundary; native token_usage_record ends it. Do not use item envelope duration or an unobserved request start inferred from a previous usage alone.
- Attach only to already accepted owned native response rows with real response_id and matching explicit Turn. Never attach to compaction, cumulative, initial or anonymous legacy usage. Boundaries are optional timing metadata and must not enter accounting Frame equality.
- Finish/reset pending output on native or new legacy usage notifications; identical repeated cumulative snapshots do not invent requests. Output within 100 ms of preceding usage is treated as same-flush supplementation, not a new request start. Task starts, aborts, completion and malformed lines reset pending state.
- Missing context may yield nil in a prefix copy. Conflicting positive estimates across copies, explicit failed Turns or per-response conflicting estimates deny association. Estimates do not claim complete Turn coverage.
- Duration must be 100...3,600,000 ms. Do not clamp. Rate is output / estimated seconds, eligible only output >=200 and duration >=1,000 ms. Includes first-token waiting/retries and is not measured generation speed.
- UI table/inspector use ≈ and describe uncertainty. Unknown is —, never zero. Keep full-Turn output/count/rate separate and unchanged.

## 4. Validation & Error Matrix

| Input | Result |
|---|---|
| Matching native output after user/context boundary | Estimate using native usage end |
| Usage precedes tool result and delayed token_count | Estimate excludes post-response tool wait |
| Duplicate native/archive | One accounting row; same positive estimate accepted |
| Conflicting copy boundaries | No estimate |
| Abort, missing Turn, damaged pending line | No inferred estimate |
| Compaction/cumulative/initial or item envelopes only | No request estimate |
| Output <200 or duration <1 s | Duration may be estimated; no rate |

## 5. Good / Base / Bad Cases

Good: tool return at 13:00:45, model output later, native usage at 13:01:30 for 2,400 output tokens → ≈45 s / ≈53.3 tok/s. Base: missing boundary → — with explanation. Bad: divide one response's output by full Turn duration or item flush interval and present it as measured speed.

## 6. Tests Required

`./Scripts/test.sh` tests native wait/end, tools, switches, delayed notifications, duplicates/legacy, same-flush, plausible bounds, exact 1 s and 200-token thresholds, abort identity, malformed pending evidence, copy conflicts, compaction and rejected envelopes. `render-ui-previews.sh` asserts the real scanner produces 45 s / 2,400÷45 and unknown remains nil, then renders table/inspector light/dark. Live aggregate coverage is evidence of availability, not exact frozen accounting equivalence.

## 7. Wrong vs Correct

Wrong: UI parses raw JSON or copies a full-Turn duration into each response.

Correct: Core attaches a distinct optional estimate to a real accepted response; UI shows ≈ and whole-Turn scope separately.
