# Scan and Filter Performance

## 1. Scope / Trigger

Read before changing timestamp parsing, calendar filtering, scan caching or loading projections. Preserve [accounting](token-accounting.md) before claiming a speed improvement.

## 2. Signatures

`ScanReport.records(in:now:sortedByTime:)` defaults to newest-first ordering; callers that own another sort can request `sortedByTime: false`. `UsagePeriod.bounds(now:timeZone:)` returns operation-local day bounds. `CodexLogScanner(timeZone:)` owns immutable ISO parsing styles and serial file cache.

## 3. Contracts

- Compute the four-period Gregorian/local-day bounds once per aggregate/filter operation. Today includes today; 7/30 days include today plus 6/29 prior local dates. Future dates are excluded from bounded periods. All retains all dates. Do not cache bounds globally across midnight or time-zone changes.
- Preserve the prior ISO8601DateFormatter millisecond precision contract: truncate textual fractional digits beyond three, parse valid supported offsets and canonicalize to nearest epoch millisecond, including pre-epoch dates. Dates must exist in the Gregorian calendar; valid leap days remain supported. Clock hours are 00...23, minutes/seconds 00...59; offset components must be in range, in ±HH:mm or supported ±HHmm form, including valid offsets through 23:59. Reject impossible dates, nonstandard 24-hour clocks, malformed offsets and out-of-range components even where the old formatter normalized or ignored them. Do not imitate those quirks or use a slow-parser fallback. Invalid timestamps remain unassigned with diagnostics; no file-time fallback for usage.
- Cache uses file path, size and modification time. Unchanged files reuse parsed metadata; changed files reparse in 64 KiB chunks, deleted files leave cache. This is file caching, not byte-incremental or persistent caching.
- Bound Foundation temporary lifetimes: wrap each FileHandle 64 KiB read and each JSON line callback in a local autoreleasepool, including an unterminated tail. Chunking alone does not release autoreleased NSData/JSON objects. Preserve retained metadata and parse/error behavior; never use pools as a substitute for bounded reads.
- Background actor owns scanning. First load and changed-root load are pending, not successful zero usage. Refresh keeps the successful report; failure does not move successful refresh time. Old-root results must not overwrite the new root.
- UI must not perform two sorts for the same request projection. Display formatting never affects counters or timestamp identity.

## 4. Validation & Error Matrix

| Condition | Expected |
|---|---|
| Fractional/offset representations of the same instant | Same millisecond identity and replay behavior |
| Midnight, DST 23/25-hour day | Gregorian local date/hour buckets remain correct |
| Missing/invalid usage timestamp | Existing missing-timestamp diagnostic, no invented date |
| Unchanged file | Cache hit and equal accounting |
| Controlled append / root switch | Correct invalidation and no stale result |
| Failed refresh after success | Previous successful data/time retained with visible error |
| First load | Pending placeholder rather than zero-result presentation |
| 350 MB fixed corpus | Bounded temporary lifetime; equal accounting before/after; measure peak footprint and maximum RSS separately |

## 5. Good / Base / Bad Cases

Good: one bound computation followed by comparisons against existing yyyy-MM-dd rows. Base: unchanged rescan rebuilds aggregates from cached token metadata. Bad: constructing date formatters for each of 7,000 records or copying successful time onto a failed scan.

## 6. Tests Required

`./Scripts/test.sh` covers parser precision, offsets, negative epochs, midnight/DST and replay. Run the native store-state harness and `./Scripts/benchmark-performance.sh` on a generated fixture only. Compare baseline/current snapshots from the same fixture: rows/order, all four periods, usage/models/sessions/day/hour and diagnostics. Benchmark release-optimized cold process scan, unchanged warm, controlled single-file append and filter/sort. Cold does not mean OS disk caches were purged. Host targets (5 s cold, 100 ms warm, 50 ms filters) are measured goals, not guarantees for all Macs. Benchmark script records /usr/bin/time -l maximum RSS and peak footprint. measure-app-memory.sh separately samples the actual built App at 10/35 seconds using a temporary UUID bundle identity; normal termination affects only its own instance. Sampling alone does not prove completed scanning or UI actions. Do not compare scanner peaks to whole-App totals or virtual address space to physical footprint.

## 7. Wrong vs Correct

Wrong: `rows.filter { period.includes(day: $0.day, now: Date()) }`, creating bounds per row and permitting midnight drift inside one operation.

Correct: capture one now and one bounds value, then filter every row against that value. Preserve the exact report before comparing measured time.
