# Implementation result

Implemented approved performance child only. Root/task/archive/release state, README/VERIFICATION and installed/running applications were not changed. No real auth/config or prompt bodies were used by the performance fixtures.

## Changes

- `Sources/Core/Models.swift`: immutable calendar day bounds calculated once per filter/aggregation operation; period semantics retain today / previous 6 / previous 29 calendar days and future-day exclusion, while all remains unrestricted. Report-level totals/models share the bounds with session aggregation. `records(..., sortedByTime: false)` lets a caller apply its own sort once; default CLI/API order remains unchanged.
- `Sources/Core/CodexLogScanner.swift`: reuse Foundation ISO8601 parse styles rather than per-file/per-event Objective-C formatter parsing. Preserve the old millisecond contract for valid timestamps by truncating fractional text after three digits, then canonicalizing floating-point dates to the nearest epoch millisecond. Negative epochs use nearest rounding after textual truncation, not toward-zero epoch truncation. Exact Date equality is regression-tested against the previous `ISO8601DateFormatter`, including sub-three-digit fractions, longer fractions, valid offsets and pre-1970 dates. Independent check added explicit Gregorian date / 00...23 clock / 00...59 minute-second validation, rejecting invalid inputs even where old Foundation normalized them. Valid colon/compact offsets through 23:59 are applied to a parsed Z wall clock, avoiding the new style's 18-hour fixed-zone limit without a slow-parser fallback. Invalid usage timestamps stay unassigned with the existing diagnostic. The inspected upstream recorder `codex-rs/rollout/src/recorder.rs:2093` emits `[subsecond digits:3]Z`; extended valid inputs retain the existing scanner's millisecond precision rather than acquiring new microsecond replay semantics.
- `Sources/App/RequestsContent.swift`: newest sort reuses report order; other sorts request unsorted period rows and sort once. One records projection per body retained; no additional stale UI cache introduced.
- `Sources/App/UsageStore.swift`: explicit successful-report presence; root changes reset report/didScan/success/error state, and obsolete scans cannot set current-root didScan. Refresh failure preserves previous successful report and timestamp. Injected UserDefaults defaults to `.standard`, allowing an isolated real-scanner test process without modifying app settings.
- `Sources/App/MenuPanelView.swift`, `DashboardView.swift`: first/root-changed load displays pending/loading instead of zero metrics or a false connected status. Successful data stays visible during refresh. Settings remain accessible on an initial error. Layout redesign/unit captions/diagnostic grouping are deferred to the approved later UI child.
- `Tests/CodexStatsCoreTests/DateFilteringTests.swift` and additions to `CodexLogScannerTests.swift`: exact formatter parity, timezone/midnight/DST/future boundaries, equivalent-text legacy replay, fractional ordering/day/hour buckets and same-size mtime/root cache invalidation.
- `Tests/UsageStore/main.swift`, `Scripts/test-usage-store.sh`: real asynchronous scanner/store state verification with synthetic temporary logs and a unique defaults suite; does not launch an installed app.
- `Tests/Performance/generate.py`, `main.swift`, `Scripts/benchmark-performance.sh`: deterministic synthetic-only workload and release scanner benchmark. Generated manifest marker is mandatory before the harness appends to a fixture; generator refuses nonempty destinations. Fixture is outside source/app bundle. The script's fourth baseline label enables an explicit equality assertion, and mismatch exits nonzero.

## Verification

The two newly added date tests first failed to compile because `bounds` / `parseTimestamp` did not exist, then passed after implementation. Subsequent replay/cache/ordering regressions passed with the final suite.

- `./Scripts/test.sh` — PASS, 75 Core tests, final `/tmp/performance-full-tests.log`.
- `./Scripts/test-usage-store.sh` — PASS: actual scanner first load, successful refresh retention on failure, current-root reset, real empty scan and obsolete completion handling; `/tmp/performance-store-tests.log`.
- `./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed /tmp/codex-stats-after-accounting/Sources/Core baseline` — release baseline, `/tmp/performance-baseline-final.log`.
- `./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed Sources/Core optimized baseline` — release optimized and automatic exact pre/post correctness PASS, `/tmp/performance-optimized-final.log`.
- `./Scripts/build-macos.sh /tmp/codex-stats-performance-build-final-20261014` — PASS, native arm64 executable target macOS 14; app at `/tmp/codex-stats-performance-build-final-20261014/Codex Stats.app`, `/tmp/performance-native-build-final.log`.
- `codesign --verify --deep --strict --verbose=2 '/tmp/codex-stats-performance-build-final-20261014/Codex Stats.app'` — PASS, valid on disk / satisfies designated requirement.

An earlier native build attempt correctly rejected a source file modified during compilation (indentation edit); final build above ran against stable sources and passed. No UI click/launch or actual macOS 14 runtime acceptance was performed by this child.

## Fixed-input release measurements

Host: arm64, macOS 27.0.1, Apple Swift 6.4. Fixture: 39 files, 65,000 JSONL lines, 349,964,213 bytes, 7,020 accepted native usage records, 9,043,780 total tokens. Cold means new scanner process/cache; OS file cache is not flushed. Workload consists exclusively of generated synthetic metadata/token records and synthetic assistant filler. Controlled append modifies exactly one generated file and restores its original length after scan.

| Operation | Baseline | Optimized |
| --- | ---: | ---: |
| Process-cold scan | 7.788 s | 3.029 s |
| Unchanged warm scan | 54.10 ms | 57.56 ms |
| One changed file reparse after append | 225.99 ms | 126.98 ms |
| Today filter + time sort | 1778.56 ms | 9.69 ms |
| 7-day filter + time sort | 2199.19 ms | 19.13 ms |
| 30-day filter + time sort | 2178.96 ms | 17.95 ms |
| All filter + time sort | 17.28 ms | 17.97 ms |

Before timing conclusions, equality assertion compared all four periods, ordered row identity/owner/model/turn/day/time/evidence/cumulative/last/token-known fields, model totals/session counts, day and hour values, session order and typed diagnostics. Independent parser tests check exact Date equality beyond benchmark's millisecond serialization. Cold <=5 s, warm <=100 ms and filtering <=50 ms targets met on this host. Initial exploratory run also measured 7.06→2.84 s cold, but the table uses only final expanded-snapshot runs. The final baseline overlapped a native compiler job for part of its run; timings are observations rather than exclusive-machine guarantees. Independent check should rerun the same baseline/optimized commands serially for uncontended corroboration.

## Limits / next handoff

Changed files still reparse fully; no byte-level incremental scanner, persistent cache, filesystem watcher or new architecture was added. Runtime model/period behavior and CLI exact values retain accounting baseline. First-load placeholder states are implemented and real-store tested, but UI native visual/interaction QA belongs to the later UI child. Performance budgets are host/workload observations, not guarantees for all Macs. Parent owns final documentation/spec reconciliation and release packaging after independent check.

## Independent check after timestamp validation fix

Final gate is **78 passing Core tests**, the native UsageStore harness and native arm64/macOS 14-target build/signature verification. The new malformed-clock scan regression failed before the fix; strict rejection of normalized invalid dates, 24-hour clocks and malformed offsets is an intentional accuracy contract, separately documented from valid-input parity. See `check-result.md` for exact commands and evidence.

The checker reran baseline and optimized commands serially, with no overlapping checker/parent compilation. Expanded snapshots remained exactly equal on the fixed valid-input workload:

| Operation | Check baseline | Check optimized |
| --- | ---: | ---: |
| Process-cold scan | 8.265 s | 3.472 s |
| Unchanged warm scan | 64.20 ms | 54.64 ms |
| One changed file reparse after append | 323.05 ms | 122.39 ms |
| Today filter + time sort | 1538.04 ms | 11.87 ms |
| 7-day filter + time sort | 4901.44 ms | 17.76 ms |
| 30-day filter + time sort | 2625.66 ms | 16.63 ms |
| All filter + time sort | 35.98 ms | 17.37 ms |

The optimized host measurements satisfy the three approved targets. Earlier measurements above remain implementation-stage observations; this serial pair is the final independent corroboration.
