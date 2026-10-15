# Scan and diagnostic research

Status: planning research only; no product source was changed. Measured on this Mac on 2026-10-14. The real log corpus was read only from the two Codex session folders; no auth/config files were read. Only counts, byte totals and timings were persisted. Temporary benchmark source/binaries contain no log bodies.

## Measured bottlenecks

A process-cold scanner (empty in-memory cache, OS disk cache not flushed) read 39 JSONL files and produced 33 logical sessions / 7,380 accepted records in the first baseline. Logs were actively growing, so later runs have slightly different counts; do not compare their total Token values as if frozen.

| Operation | Original release-optimized source | Isolated temporary experiment |
| --- | ---: | ---: |
| Cold whole scan | 8.205 s | 3.713 s with reusable native ISO date parse styles |
| Warm scan, all files unchanged | 36–43 ms | unchanged scanner cache |
| Warm scan when two files changed | 3.688 s, 37/39 cache hits | demonstrates full reparse of changed files |
| Request records, today | 1.395 s | 4.8 ms with one period-bound calculation |
| Request records, 7 days | 2.264 s | 14.2 ms with one period-bound calculation |
| Request records, 30 days | 2.307 s | 16.5 ms with one period-bound calculation |
| Request records, all time | 13.7 ms | 17.0 ms; no original date filtering cost |
| Totals/models/daily/session filtering | generally 12–30 ms per operation | not separately optimized in experiment |

An instrumented cold scan of 65,410 lines / 349,795,577 line bytes measured 8.284 s overall: 8.180 s inside `parseFile`, including 4.495 s in ISO timestamp parsing and 1.716 s in `JSONSerialization.jsonObject`. Remaining parse work includes dictionary bridging, payload/frame extraction and line processing; do not call that remainder disk I/O. Post-parse aggregation/enumeration was about 0.1 s. Counts were 30,335 event_msg, 26,436 response_item, 7,662 token_usage_record, 525 turn_context, 52 session_meta and other non-usage rows.

### Source anchors

- `Sources/Core/Models.swift:164–183`: `UsagePeriod.includes` computes calendar start/bounds and constructs two DateFormatter instances for every candidate day.
- `Sources/Core/Models.swift:240–244`: `ScanReport.records` calls that function separately for every accounting row, then sorts.
- `Sources/App/RequestsContent.swift:20–32`: a view computed property filters those records and sorts again; each body update repeats the operation on the UI actor.
- `Sources/Core/CodexLogScanner.swift:50–61`: unchanged files cache `ParsedLog`; any changed file is reparsed in full.
- `Sources/Core/CodexLogScanner.swift:178–187`: every complete JSON line is decoded and timestamp-parsed, including response bodies not needed for Token accounting.
- `Sources/App/UsageStore.swift`: scan work already runs on a background actor. First loading currently exposes `ScanReport.empty` (zero values), while `didScan` and `loading` already permit explicit pending state. A slow result is not proof the scanner runs on the main actor.

### Simple first changes

1. Compute local Gregorian inclusive day bounds once per filtering/aggregation operation, using the same POSIX `yyyy-MM-dd`, current time zone and today/6/29-day rules. Pass that immutable predicate to existing loops. Avoid mutable global date caches that become stale across midnight, time-zone changes or root changes. Preserve empty-range/calendar failure behavior visibly and cover DST/local boundaries.
2. Remove the second newest sort or expose an unsorted core projection and sort only after UI filters. Prefer one UI projection per report revision/filter state; avoid a cached view that no longer responds to refresh, query/model changes or midnight.
3. Reuse native `Date.ISO8601FormatStyle` parsing for fractional and whole seconds. A temporary replacement reduced cold parsing from about 8 s to 3.6 s. Real timestamp checks showed zero failures, fractional digits always 3, and a maximum Date difference of 1.1920928955078125e-7 s (floating-point conversion, no >=1 ms differences, no hour bucket changes). An additional same-pass real-corpus check showed zero local calendar day/hour differences across 65,777 parsed timestamp calls. On the stable sanitized `/tmp/codexpulse-frozen` corpus, original and candidate parsers yielded 29 files / 29 sessions / 6,714 records / 890,273,713 total Tokens; 6,771 comparison checks passed (all four periods at two reference dates, model/daily totals, record identity/order/usage/model/day/evidence/compaction, per-session daily/hourly buckets and warnings). Exact Date equality is not bit-identical to the old parser, so validate ordering/replay dedup, local day/hour boundaries, offsets, invalid timestamps and fractional precision before committing. Do not introduce a silent parser fallback that accepts previously invalid values without a stated contract.
4. Show initial `loading` as reading/progress placeholders rather than real-looking zero consumption; keep last successful data visible during refresh and preserve explicit read errors. This improves honesty, not measured completion time.

Defer a persistent cache/incremental reader until the simple measured changes are assessed. Append-only parsing is more complex than retaining an offset: it must preserve turn/model/session state, a partial last line, newly emitted compaction markers affecting earlier frames, fallback format selection, truncate/rewrite detection, cache invalidation, global response-ID dedup and inherited context. Do not skip arbitrary lines through a substring such as `token_count`; JSON key order/escaping/unknown types can change, and current damaged-line reporting would be lost. If cold parsing still misses the accepted latency target, benchmark a native typed envelope decoder or metadata-only disk cache with explicit invalidation before choosing one.

## Why the seven warnings appear

The first run's seven warnings were exactly three `history_base` messages and four different-copy messages, with zero corrupt lines. They do not indicate seven failed model requests.

### `history_base` is currently unconditional

`Sources/Core/CodexLogScanner.swift:242` warns whenever the field exists; it does not check whether its referenced immutable prefix exists locally. A metadata-only read of the live 39 files found six physical files containing history_base. Five referenced rollout files were present (same stable session identity, byte boundary within file); one reference was missing. Selection of one logical copy reduced those to three visible warnings. Presence alone therefore cannot justify “missing history” severity or wording.

The previously checked primary Codex source confirms the distinction:

- `/tmp/codexpulse-codex/codex-rs/protocol/src/protocol.rs:3225–3243`: `HistoryPosition.thread_id` identifies immutable **rollout_id**, not necessarily stable `SessionMeta.id`; it contains `end_ordinal_exclusive` and `end_byte_offset`.
- The same file around `SessionMeta.history_base` describes an exclusive prefix of another paginated rollout.
- Revert retains a stable thread identity but can create another physical rollout ID. A logical fork boundary is independent of physical history_base.

Primary source was inspected at upstream Codex revision `2f05c0a71f59fb2f05800846351f3e9926c3e52b` in the existing local clone. This is not a claim about every installed Codex release.

### Copy mismatch is not always an appended duplicate

`Sources/Core/CodexLogScanner.swift:66–76` treats every file with the same stable session ID as a duplicate, chooses the file with more frames, and emits a warning whenever Frame arrays differ. Six physical same-session comparison pairs were found: one was a mathematical full Frame prefix with an empty accounting stream (0 frames), while five nonempty comparisons had disjoint native response-ID sets (zero overlap). Those five pairs collapse into four logical-session warnings. A separate native-record-only check found zero conflicting duplicate response IDs in the physical corpus. Do not silently downgrade these disjoint streams as harmless “old copies”; longest-copy selection can discard real physical-generation expenditure and also may choose an older generation over a newer shorter one.

### Same-pass native expenditure comparison

A temporary instrumented scanner compared all physical parsed logs with its own selected-copy report from **the same scan**, avoiding between-run append drift:

| Metric | Value |
| --- | ---: |
| Distinct genuine response IDs owned by each physical log's stable session | 7,705 |
| Genuine native response IDs accepted by selected-copy report | 7,441 |
| Duplicate native response IDs across physical files | 0 |
| Conflicting overlapping native usage/owner/model/timestamp | 0 |
| Distinct owned native records omitted by copy selection | 264 |
| Omitted input / output | 33,506,077 / 160,663 |
| Omitted cached input / reasoning (subsets, not added again) | 32,241,408 / 46,636 |
| Omitted input + output | **33,666,740 Tokens** |

This is an aggregate upper-bound/difference observation for native physical records on this corpus, not universal proof that blindly unioning every physical file is valid. An independent response ID can identify real incurred expenditure after revert, but a retained-history projection intentionally excludes some reverted turns. Same-ID conflicting usage, stale metadata ownership, fork/inherited foreign records, malformed/zero/invalid-time records and legacy cumulative streams require explicit rules. The instrument filtered genuinely owned nonzero native entries with valid timestamps; current report rows were all native in this scan. No real session IDs, filenames, project names or log bodies were persisted.

A dedicated accounting/lineage child should settle expenditure versus retained-conversation semantics and implement tested physical rollout reference resolution. Do not downgrade current nonempty disjoint-copy warnings just because metadata references exist.

### Recommended diagnostic contract

Use a typed diagnostic model, not string-contains classification:

- Informational `historyReference`: a history_base is declared. Explain local observable usage and point to lineage metadata; do not claim missing history if reference resolution has not been done.
- Informational `supersededCopy`: accounting-safe equivalent or strict ancestor prefix was verified; one source was selected, no extra Token charge.
- Warning `unresolvedHistoryReference`: an actual referenced prefix needed to reconstruct accounting is missing, malformed or outside the permitted folders/boundary.
- Warning `divergentAccountingCopies`: non-prefix accounting histories cannot be safely selected/merged; list count/details in one expandable diagnostics area. Retain the ambiguity and possible undercount.
- Warning/error for invalid usage, missing timestamps, overflow, unavailable directories and unreadable/corrupt files remains explicit. Model unknown is a normal field value unless a separate accounting ambiguity exists.

Group by diagnostic kind/severity, show an overview summary and details in settings/expandable panel, rather than one large orange banner per session. Severity reduction must follow evidence and must not hide lost/unverified expenditure.

## Accounting-safe ancestor definition

For **unchanged-generation appended copies**, compare typed accounting streams, not prompt text. Exact Frame equality already covers timestamp, model context, turn, response ownership/ID, raw request/cumulative values, known-field flags and compaction status. A safe narrow first rule is strict full-frame prefix plus consistent session/fork/history-base metadata and valid boundaries. Compare all those fields; equal numeric total alone or equal response ID with conflicting usage is insufficient. An empty stream is not enough to claim equivalent history when the parse was damaged/incomplete.

For **paginated physical generation chains**, full-stream prefix does not apply: the successor stores a suffix and refers to an immutable prefix by rollout ID, ordinal and byte boundary. Supporting it requires indexing physical rollout IDs separately from logical session IDs, validating reference boundaries and cycle/missing-reference cases, and preserving native response ownership. Two distinct product questions must stay explicit:

1. Local total historical expenditure includes real owned independent response records even if a turn was later reverted; native response IDs can deduplicate copied records.
2. Current retained conversation projection includes only a specified lineage prefix plus suffix.

Do not substitute one for the other without an agreed requirement. Legacy cumulative-only streams cannot be naively unioned because counters may reset/replay and have no independent response identity. Recommend a separately scoped accounting/lineage child with fixtures before changing the current total. If excluded from this release, document longest-copy selection's undercount risk and retain its warning.

## Verification needed during implementation

- Time-range boundary fixture: today, yesterday, 6/7 and 29/30 days, midnight, future rows, DST and time-zone changes; results match previous filter.
- Representative >7,000 rows: benchmark core selection and UI projection with release optimizations; target <50 ms for request filtering/sorting on this Mac.
- Scan benchmark: process-cold, unchanged warm and exactly one controlled appended file; immutable synthetic fixture validates totals/records/models and cache hit counts.
- ISO date fixtures: whole/fractional seconds, Z/offsets, invalid dates, near-midnight/hour-boundary values; preserve local date assignment and replay pair decisions.
- Diagnostics fixtures: equal copy, strict frame prefix, same total/different request IDs, conflicting same response ID, different time/model/ownership, empty/malformed copy, resolved/missing history_base, physical successor with disjoint suffix, cycles/out-of-range byte/ordinal boundaries.
- Typed severity grouping must preserve details; test actual warning transitions rather than matching string substrings in UI.

## Reproduction

Temporary artifacts are in `/tmp/codex-stats-scan-research/`; baseline harness was compiled against unmodified sources:

```sh
xcrun swiftc -O Sources/Core/*.swift /tmp/codex-stats-scan-research/main.swift -o /tmp/codex-stats-scan-research/benchmark
/tmp/codex-stats-scan-research/benchmark
```

The harness times a single `CodexLogScanner` cold scan, three subsequent scans, and `report.records/totals/models/dailyTotals/recentSessions` for each period, outputting only elapsed seconds/counts/aggregate total. JSON/date timing and prefix experiments were applied only to source copies in `/tmp`. Production code, app artifacts and real logs were untouched. Temporary results are representative observations, not automated performance acceptance proof on macOS 14.
