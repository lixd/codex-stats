# Independent check result

**PASS after the local timestamp-validation repair.** The performance child can hand off to the dependent UI child. This is a source, test, native-build and synthetic-performance gate; it is not installed-app interaction or macOS 14 runtime acceptance.

## Scope reviewed

Reviewed the task PRD/design/implementation/context documents and the referenced requirements, design, display, accounting and research contracts. Compared current Core with `/tmp/codex-stats-after-accounting/Sources/Core`; checked App changes against the retained pre-analytics source backup. Product changes are limited to `Sources/Core/Models.swift`, `Sources/Core/CodexLogScanner.swift`, `Sources/App/UsageStore.swift`, `RequestsContent.swift`, `MenuPanelView.swift` and `DashboardView.swift`. Added/extended tests and harnesses live in `Tests/CodexStatsCoreTests/DateFilteringTests.swift`, `CodexLogScannerTests.swift`, `Tests/UsageStore/main.swift`, `Tests/Performance/generate.py`, `Tests/Performance/main.swift`, `Scripts/test-usage-store.sh` and `Scripts/benchmark-performance.sh`.

Confirmed operation-local period bounds, preserved default newest-first record ordering, one request projection / one sort, prior successful report retention on refresh failure, root-result invalidation and isolated test UserDefaults. Core accounting rules and CLI product code remain unchanged by this child. Timestamp display units and further layout/timing/diagnostic presentation belong to the next child. No Git initialization, task-state/archive/release changes, installed-app changes or real log mutations were performed.

## Defect found and fixed

The faster Foundation parser normalized invalid `25:00:00`, `00:60:00` and `00:00:60` clocks into dates even though the previous formatter rejected them. This could assign malformed consumption to a valid accounting day. The new parser/scan tests failed before the fix (2 failing tests / 12 assertion issues in `/tmp/performance-check-parser-before.log`).

With root's explicit scope decision, the parser now validates fixed-width Gregorian date and clock components before parsing, including leap years and actual month length. It accepts valid ±HH:mm and supported ±HHmm offsets through 23:59 by parsing a Z wall clock and applying the numeric offset. It rejects impossible dates, 24-hour forms, malformed offsets, out-of-range components and trailing junk. There is no slow-parser fallback. Usage with an invalid timestamp remains unassigned and receives the existing `missingTimestamp` diagnostic.

This intentionally rejects old Foundation normalization quirks for invalid dates/times/offsets. It preserves valid supported timestamp precision and exact Date identity: fractional text beyond three digits is truncated and the parsed epoch is rounded to its nearest millisecond, including negative epochs. Three new tests cover invalid-clock rejection, scan-level exclusion/diagnostics, valid leap days and high offsets versus deliberately rejected old normalization. A temporary independent audit additionally compared 6,006 valid timestamp combinations spanning pre/post-epoch dates, fractions and offsets with no Date mismatch; malformed input differences were examined separately.

The updated `.trellis/spec/backend/scan-performance.md` accurately reflects these contracts. No further spec amendment is required.

## Commands and results

- `./Scripts/test.sh --filter 'timestamp|outOfRangeTimestamp'` — PASS, 4 focused tests after repair; `/tmp/performance-check-parser-after.log`.
- `./Scripts/test.sh > /tmp/performance-check-full-tests.log 2>&1` — PASS, 78 tests / 0 failures.
- `./Scripts/test-usage-store.sh > /tmp/performance-check-store-final.log 2>&1` — PASS: real asynchronous scanner first load, refresh retention, failure, root reset, successful empty report and obsolete result states.
- `./Scripts/build-macos.sh /tmp/codex-stats-performance-review/native > /tmp/performance-check-native.log 2>&1` — PASS, native arm64 build targeting macOS 14 and ad-hoc app signature.
- `codesign --verify --deep --strict --verbose=2 '/tmp/codex-stats-performance-review/native/Codex Stats.app'` — PASS, valid on disk and satisfies designated requirement.
- `bash -n Scripts/benchmark-performance.sh Scripts/test-usage-store.sh` — PASS.
- `./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed /tmp/codex-stats-after-accounting/Sources/Core check-baseline > /tmp/performance-check-baseline.log 2>&1` — PASS, release baseline.
- `./Scripts/benchmark-performance.sh /tmp/codex-stats-performance-fixed Sources/Core check-optimized check-baseline > /tmp/performance-check-optimized.log 2>&1` — PASS, release optimized plus automatic expanded JSON equality assertion.

The last two commands ran **serially**, after other compilation/tests finished; parent avoided heavy tools during this pair. Host: arm64 macOS 27.0.1 / Swift 6.4. Generated workload: 39 files, 65,000 lines, 349,964,213 bytes, 7,020 accepted records, 9,043,780 tokens. Controlled append changes one generated file then restores its original length. No actual Codex log was modified.

| Operation | Baseline | Optimized |
| --- | ---: | ---: |
| Process-cold scan | 8.265 s | 3.472 s |
| Unchanged warm scan | 64.20 ms | 54.64 ms |
| Controlled single-file append/reparse | 323.05 ms | 122.39 ms |
| Today filter + time sort | 1538.04 ms | 11.87 ms |
| 7-day filter + time sort | 4901.44 ms | 17.76 ms |
| 30-day filter + time sort | 2625.66 ms | 16.63 ms |
| All filter + time sort | 35.98 ms | 17.37 ms |

Automatic pre/post equality covered all four periods, ordered row identities/owners/models/turns/dates/millisecond instants/evidence/cumulative and last usage/known-field flags, model totals/session counts, sessions, daily/hourly buckets and typed diagnostics. Exact valid-input Date parity is independently tested, rather than inferred from millisecond snapshot serialization. The intentional invalid-input rejection delta is outside this valid synthetic snapshot comparison.

## Limits

The optimized process-cold ≤5 s, unchanged warm ≤100 ms and filter ≤50 ms budgets passed on this host/workload. Process-cold means a new scanner and empty in-process parsed-file cache, not purged operating-system disk caches. These are observations, not guarantees on every Mac or a claim of unconstrained exclusive-host performance. Changed files still reparse fully; caching is file-level and in-memory.

First-load/refresh/error state transitions have real scanner/store proof. Native visual layout, menu/window interactions, installation and macOS 14 runtime acceptance remain for later validation. Parent's independent native-log accounting audit is separate from this synthetic benchmark gate.
