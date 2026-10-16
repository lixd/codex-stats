# Local Token Accounting

## 1. Scope / Trigger

Read this contract before changing JSONL decoding, deduplication, physical history, diagnostics, or the Core-to-App/CLI report. The application measures retained local expenditure, including verified requests later reverted. It does not reconstruct the current conversation or subscription charges.

## 2. Signatures

`CodexLogScanner.scan(homePath: String) throws -> ScanReport` owns decoding and accounting. `ScanReport.diagnostics: [ScanDiagnostic]` is structured; `warnings: [String]` projects warning/error messages for existing consumers. CLI `codex-stats-report <root> --records` exports exact integer usage and typed diagnostics. App code must not decode raw payloads or classify diagnostic message text.

## 3. Contracts

- Read only regular JSONL files in `sessions`/`archived_sessions`, or the explicitly selected JSONL directory. Never read credentials or retain conversation bodies.
- `total = input + output`; cached input is a subset of input and reasoning is a subset of output. Preserve unknown-field flags rather than inventing zero observations.
- `TokenUsage.difference(from:)` returns nil for input/output resets. With monotonic parents, a known subset delta that decreases or exceeds its parent's delta becomes unknown (internal zero), independently for cached/reasoning. Preserve the parent delta; do not clamp a subset and still report known. Scanner emits `counterAmbiguity` for a known-to-unknown inconsistency, including native subtraction. Missing fields alone are not a new counter anomaly. Raw snapshots remain unchanged.
- Covered cumulative and last-only companions seed the same Turn/model/usage replay evidence as later anonymous last-only notifications. Independent response IDs and credible cumulative growth still count; rejected ownership cannot reenter through replay. A zero-parent inconsistent subset emits a diagnostic without inventing a zero request or rewriting prior accepted rows. Later valid deltas use the new raw baseline; earlier nonzero unknown rows continue to make aggregate subsets unknown.
- Explicit nonempty `session_meta.id` (or `session_id`) fills `SessionUsage.recordedSessionID` and groups verified sessions. Grouping distinguishes recorded IDs from unknown filename stems using a typed key. Unknown same-stem active/archive copies share one conservative selected legacy stream; this is not proof of real session identity. Their opaque internal IDs start at `unidentified:<stem>`, repeatedly prefixed on collision against all recorded and already allocated IDs. Unknown groups must never select a verified legacy stream or contribute response conflicts/compaction evidence. Session/record internal IDs are not user-facing identities. Hand-built SessionUsage defaults recordedSessionID to nil.
- The UUID suffix of a canonical rollout filename identifies immutable physical history; `history_base` refers to that physical UUID with exclusive byte/ordinal boundaries.
- Owned `token_usage_record` requires an explicit `thread_id` matching a nonempty recorded metadata ID and a valid `response_id`. Comparing an owner against the filename or internal fallback ID is forbidden. Global response-conflict and compaction normalization use the same recorded-ID ownership gate. Deduplicate real responses globally across active, archived and reverted physical files.
- Native usage comes from per-response usage, never from differences between `thread_token_usage` and `total_token_usage`. Matched cumulative notifications are suppressed. Rejected foreign/unknown native rows, including missing session metadata, retain provenance so an adjacent counter before or after them cannot resurrect their usage. Only a genuinely verified owner with malformed response/usage may leave an independent valid legacy counter eligible.
- A later positive compaction marker applies to matching response copies, including a shorter archive ending before the marker. Explicit payload model is authoritative; otherwise compaction usage is `Unknown model`. Contradictory explicit models remain conflicts.
- Genuine contradictory response usage/owner/Turn/time/model is excluded with a warning for every contributing source. Distinct response IDs are independent expenditure even when cumulative totals coincide.
- Metadata parent references may resolve only a candidate whose recordedSessionID exactly equals the declared parent ID; generated unknown internal keys never prove parent identity or inherited-prefix coverage.
- Unidentified legacy counters use one deterministic selected stream. Do not union divergent legacy histories or merge extra native rows when overlap with accepted legacy consumption is unprovable.

## 4. Validation & Error Matrix

| Condition | Behavior |
|---|---|
| Same response/cumulative notification repeated | Count once |
| Separate native physical generations | Merge verified distinct owned responses |
| Equivalent complete nonempty frame prefix | Information: superseded copy |
| Resolved local history reference | Information; no missing-history warning |
| Missing/invalid byte-ordinal reference or nonempty cycle | Unresolved-history warning |
| Corruption after referenced exclusive prefix | Keep prefix valid; report corruption separately |
| Empty zero-byte/zero-ordinal reference | Imports nothing; stop traversal |
| Native ownership absent/foreign or session metadata absent | Exclude native usage and matching companion notifications; never infer owner from filename |
| Missing-metadata filename equals a real session ID | Keep groups separate; unverified response/model/compaction cannot poison the verified group |
| Conflicting genuine response | Exclude all copies; explicit incomplete warning |
| Damaged/partial JSONL | Preserve valid rows; typed corruption/partial-write diagnostic |
| Unprovable legacy coverage | Conservative selected stream; possible-undercount warning |

## 5. Good / Base / Bad Cases

Good: one stable session has physical A with response X and reverted physical B with response Y; both owned responses count once. Base: identical archived copy contributes zero new expenditure. Bad: the same response has two contradictory valid usages; neither is charged and both sources receive warnings.

## 6. Tests Required

Run `./Scripts/test.sh` and native build after decoder/report changes. Assert exact record/global/session/model/day/hour sum agreement and unique internal row identities. Cover archive repeats, independent generations, model switches, resets, cached/reasoning subsets, missing owner/model/metadata, filename collision with and without a verified copy, identical/prefix unknown archive copies, arbitrary recorded IDs matching internal-key prefixes, prior/following cumulative and last-only companion suppression, malformed rows, inherited notifications, physical reference bounds/cycles, corruption before/after reference boundaries, compaction markers absent from a shorter prefix, and true conflicting explicit models. Compare fixed corpora in the same read; live logs may grow between runs. The 2026-10-15 identity implementation passed all 121 Core tests; App-target package compilation is not live UI or macOS14 acceptance evidence.

## 7. Wrong vs Correct

Wrong: choose the longest stable-session file and discard all other physical histories, or sum every cumulative snapshot.

Correct: preserve independently identified native responses from every physical generation, globally deduplicate them, and keep unidentified legacy coverage conservative with explicit diagnostics.

Wrong: treat absence of a later compaction marker in an archived prefix as contradictory evidence.

Correct: normalize positive compaction evidence before comparing copies, preserving explicit payload model and genuine usage/ownership conflicts.
