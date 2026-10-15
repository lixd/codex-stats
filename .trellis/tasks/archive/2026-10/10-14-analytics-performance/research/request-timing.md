# Research: request duration and token throughput

- Query: Can local Codex JSONL supply honest per-response duration and tok/s, as requested with CC Switch reference screenshots?
- Scope: local project + local primary Codex source + metadata-only survey of local sessions and archived_sessions
- Date: 2026-10-14
- Role: planning research only; no product code changes, task activation, account/config/auth access, or API cost work.

## Findings

### 1. Request usage does not contain request timing

`Sources/Core/Models.swift:112-129` defines UsageRecord without duration fields. `Sources/Core/CodexLogScanner.swift:113-125,215-224` consumes per-response usage and optional real response/turn ownership IDs. Therefore the current lack of latency is expected; the UI is not merely hiding already-parsed values.

The primary local Codex source checkout is `/tmp/codexpulse-codex`, commit `2f05c0a71f59fb2f05800846351f3e9926c3e52b`. Its `codex-rs/protocol/src/protocol.rs:2389-2398` TokenUsageRecord contains thread_id, turn_id, session_id, root_turn_id, response_id, usage, turn_token_usage, thread_token_usage. No request start, duration, or TTFT field exists. `RawResponseCompletedEvent` at `protocol.rs:2045-2049` also does not contain request timing. It is transient and not durably persisted (`codex-rs/rollout/src/policy.rs:187`).

A metadata-only scan of 39 regular JSONL files under the two permitted roots read approximately 349 MB. At that point it found 7,637 token_usage_record and 441 task_complete events. The request-record payload key union exactly matched the schema above; none had duration/elapsed/latency/start/end keys. No prompt, response text, request/session ID, cwd, file path, or account data from real sessions is persisted in this research.

These counts describe raw files including duplicate copies/inherited rows, NOT the application's deduplicated totals. Files are live and later surveys saw 7,656 usage rows; slight count drift is expected.

### 2. Turn duration is authoritative, but not request duration

`TurnCompleteEvent` at `protocol.rs:2269-2295` includes started_at/completed_at (Unix seconds), duration_ms, and time_to_first_token_ms. `TurnStartedEvent` at `protocol.rs:2299-2324` supplies turn_id and optional started_at. `TurnAbortedEvent` at `protocol.rs:4358-4381` has turn-level duration as well. Do not confuse the latter with request metadata or display it as a successful completed request.

Turn duration is measured with a monotonic Instant (`codex-rs/core/src/turn_timing.rs:121-136`) and includes the whole turn, including tools and waiting. The local raw-file survey found from 1 through 704 distinct response IDs within one turn in a file. A whole-turn latency therefore must never be copied onto each request record or used with one request's output numerator.

A safe feature is a separately labeled **Turn duration** and optional **Turn average output throughput**: sum deduplicated owned outputs for the complete same turn divided by duration_ms/1000. This is an end-to-end turn average, including tool time, not model generation speed. Missing/incomplete turn history makes even this numerator incomplete; suppress the average if completeness cannot be established, while still showing the recorded whole-turn duration with scope clearly stated. TTFT must say **Turn first token**, not per-request TTFT.

### 3. Assistant item timing is not a credible request-speed estimator

`ItemCompletedEvent` at `protocol.rs:2059-2077` contains thread_id, turn_id, item, started_at_ms, completed_at_ms. In paginated rollouts it is persisted (`rollout/src/policy.rs:230-305`), while ItemStarted is transient (`policy.rs:212`). Its item variants include Reasoning, AgentMessage and tool items; tool duration belongs to commands/MCP calls, never model requests.

Primary source starts assistant item timing when handling an upstream OutputItemAdded event (`core/src/session/turn.rs:2936-3000`), not when issuing a model request. Completion can be buffered or deferred. `core/src/session/mod.rs:2745-2757` sets start equal to completion if a start is missing. The JSONL outer timestamp itself is a writer-time timestamp (`rollout/src/recorder.rs:2091-2100`), not API start/end time.

I tested an exploratory estimator strictly in memory: between consecutive usage accounting boundaries, select same-owner/same-turn Reasoning/AgentMessage item intervals and take earliest positive start to latest completion. Among a later live snapshot of 7,656 owned raw usage rows:

- 7,036 had corresponding assistant items; 6,796 had a positive envelope.
- 240 had only zero/invalid assistant timing, 620 had no assistant items.
- 38 boundaries contained other owner/turn item events, showing additional correlation ambiguity.
- Positive envelope durations: median 3.199 s, p95 32.052 s, maximum 5,177.744 s.
- Output/envelope throughput: median 131.261 tok/s, p95 32,700 tok/s, maximum 3,534,000 tok/s.
- Anonymized counterexample: 531 output tokens with a 1 ms item interval yields 531,000 tok/s. Another: 616 output tokens over 77 ms yields 8,000 tok/s.

This fails the intended interpretation. Do not ship this estimator, clamp its results to a plausible speed, or impose an arbitrary minimum duration to mask the failure.

### 4. Recommended product contract / user decision

Default recommendation: preserve request rows and show **—** for unavailable request duration/speed with a clear explanation; add recorded turn performance to the detail panel as a distinct scope. Move request detail from a modal sheet to a right-side inspector as requested; the inspector itself is independent of timing-source availability.

The user should choose whether whole-turn performance is useful, or whether they explicitly want a best-effort estimated model-phase interval. The latter would require additional design and validation using reliable turn/tool boundaries. Never silently infer from two successive request timestamps: that includes tool execution, approvals, user idle time, and concurrency. Neither available primary source nor the screenshot proves CC Switch's estimator algorithm. Matching its visual layout is possible; claiming numerically equivalent speed is not currently supported.

If approximation is later accepted, the model must retain `timingEvidence` and provenance, the UI must display ≈ and “estimated / includes boundary limitations,” unknown/ambiguous cases must remain nil, and there must be no guessed delay for compaction, inherited history, cumulative rows, or repeated snapshots.

## Proposed checks before implementing timing

1. Real response identity is never inferred from an item ID, turn ID or file name.
2. Exact turn duration and TTFT appear only as turn-scoped fields; positive valid ms required, TTFT cannot exceed duration.
3. Several responses within one turn do not each acquire full turn latency or share a request-level average.
4. Tool `duration`, `durationMs`, waiting and approvals are not model duration.
5. No per-response interval from previous request timestamp, missing response start, or item-only 0/1 ms buffering.
6. Concurrent owners/turns, fork inherited events, repeated real response IDs, archived copies and compaction cannot duplicate throughput numerators.
7. CumulativeDelta/initialSnapshot cannot claim per-request speed, since a row may cover several responses.
8. Incomplete turn history, partial writes, aborted turns, negative/zero/missing timing and mismatched IDs remain explicitly unknown; arithmetic never divides by zero or fabricates success.
9. Request detail inspector supports dismissal/Escape/selection changes and preserves the list's search/filter/scroll state; static screenshots are distinct from actual interaction acceptance.

## Files found / related specs

- `Sources/Core/Models.swift` — record and aggregate schema, no timing fields.
- `Sources/Core/CodexLogScanner.swift` — response ownership and accounting boundaries; raw content is not retained.
- `Sources/App/RequestsContent.swift:74-123` — current request table and modal detail; sidebar change belongs here.
- `docs/design.md` — offline read-only, conservative accounting and missing data contracts.
- `.trellis/spec/frontend/token-display.md` — shared compact versus exact units and verification; unrelated to latency semantics.
- `.trellis/spec/backend/index.md` — initialization placeholders; not evidence of a completed timing standard.
- `.codex/agents/trellis-research.toml` — research-only write boundary and persisted findings requirement.

## Caveats / Not Found

No durable exact per-response latency or generation-throughput source was found in the actual local log schema. No CC Switch timing implementation was consulted; screenshot values alone do not specify its algorithm. No account configuration/authentication files, network APIs or real message bodies were exported. Surveys were independent metadata-only in-memory reads of live raw files, not benchmark data or a frozen canonical report. This document recommends a truthful scope decision; it is not implementation approval or proof that a new timing feature works.
