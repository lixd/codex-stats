# Local Token Accounting

## 1. Scope / Trigger

Read this contract before changing JSONL decoding, deduplication, physical history, diagnostics, or the Core-to-App/CLI report. The application measures retained local expenditure, including verified requests later reverted. It does not reconstruct the current conversation or subscription charges.

## 2. Signatures

`CodexLogScanner.scan(homePath: String) throws -> ScanReport` owns decoding and accounting. `ScanReport.diagnostics: [ScanDiagnostic]` is structured; `warnings: [String]` projects warning/error messages for existing consumers. CLI `codex-stats-report <root> --records` exports exact integer usage and typed diagnostics. App code must not decode raw payloads or classify diagnostic message text.

## 3. Contracts

- Read only regular JSONL files in `sessions`/`archived_sessions`, or the explicitly selected JSONL directory. Never read credentials or retain conversation bodies.
- `total = input + output`; cached input is a subset of input and reasoning is a subset of output. Preserve unknown-field flags rather than inventing zero observations.
- Stable `session_meta.id` groups sessions. The UUID suffix of a canonical rollout filename identifies immutable physical history; `history_base` refers to that physical UUID with exclusive byte/ordinal boundaries.
- Owned `token_usage_record` requires an explicit `thread_id` matching the containing session and a valid `response_id`. Deduplicate real responses globally across active, archived and reverted physical files.
- Native usage comes from per-response usage, never from differences between `thread_token_usage` and `total_token_usage`. Matched cumulative notifications are suppressed. Rejected foreign/unknown native rows retain provenance so an adjacent counter cannot resurrect them.
- A later positive compaction marker applies to matching response copies, including a shorter archive ending before the marker. Explicit payload model is authoritative; otherwise compaction usage is `Unknown model`. Contradictory explicit models remain conflicts.
- Genuine contradictory response usage/owner/Turn/time/model is excluded with a warning for every contributing source. Distinct response IDs are independent expenditure even when cumulative totals coincide.
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
| Native ownership absent/foreign | Exclude; never infer owner |
| Conflicting genuine response | Exclude all copies; explicit incomplete warning |
| Damaged/partial JSONL | Preserve valid rows; typed corruption/partial-write diagnostic |
| Unprovable legacy coverage | Conservative selected stream; possible-undercount warning |

## 5. Good / Base / Bad Cases

Good: one stable session has physical A with response X and reverted physical B with response Y; both owned responses count once. Base: identical archived copy contributes zero new expenditure. Bad: the same response has two contradictory valid usages; neither is charged and both sources receive warnings.

## 6. Tests Required

Run `./Scripts/test.sh` and native build after decoder/report changes. Assert exact record/global/session/model/day/hour sum agreement and unique internal row identities. Cover archive repeats, independent generations, model switches, resets, cached/reasoning subsets, missing owner/model, malformed rows, inherited notifications, physical reference bounds/cycles, corruption before/after reference boundaries, compaction markers absent from a shorter prefix, and true conflicting explicit models. Compare fixed corpora in the same read; live logs may grow between runs.

## 7. Wrong vs Correct

Wrong: choose the longest stable-session file and discard all other physical histories, or sum every cumulative snapshot.

Correct: preserve independently identified native responses from every physical generation, globally deduplicate them, and keep unidentified legacy coverage conservative with explicit diagnostics.

Wrong: treat absence of a later compaction marker in an archived prefix as contradictory evidence.

Correct: normalize positive compaction evidence before comparing copies, preserving explicit payload model and genuine usage/ownership conflicts.
