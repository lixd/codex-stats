# v0.2.11 integration verification

Status: **PASS — implementation, measured checks and final independent full-scope review completed.** 2026-10-15.

## Provenance and scope

- Base: `11f2a937971c40b29a2b4d69ff6bb79c5eaec91f`, v0.2.10/build12. Branch: `codex/small-beautiful-fixes`. Current source and isolated build: v0.2.11/build13.
- User explicitly approved the audit's five packages A01–A06. A07 remains deferred. Requirements/design were updated before implementation; no additional feature scope was inferred.
- No production App installation, replacement, launch or termination; no real log mutation; no staging, commit, push or publication. Only unique test-identity processes were launched and normally terminated. Before/after read-only CodexStats PID inventories were empty.
- Baseline source extracted from Git HEAD into `/tmp/codex-stats-fixes-20261015/baseline`. Corrected accounting/pre-index checkpoint hashes independently verified. [Reconstruction patch](research/accounting-before-index.patch) can be applied to that Git baseline to reproduce this checkpoint; it is not a second runtime implementation.
- [Environment](evidence/environment.txt), [final product hashes](evidence/final-source-hashes.json), [baseline metadata](evidence/baseline.json). Host macOS 27.0.1, arm64, Apple Swift 6.4 / SDK27. No history result is counted as a current pass below.

## Current correctness and UI results

| Execution | Actual result |
|---|---|
| `Scripts/test.sh` | [133 Core tests passed](evidence/core-tests.txt), 0 failures; package App also compiled |
| `Scripts/test-token-display.sh` | [3 locales × 16 cases](evidence/display-tests.txt), shared chart/unknown/exact values passed |
| `Scripts/test-menu-lifecycle.sh` | [PASS](evidence/menu-tests.txt): real owned AppKit windows, close order, replacement probe, residency and termination |
| `Scripts/test-usage-store.sh` | [PASS](../10-15-session-status-fixes/verification.md): real scanner, retry retains report/error/time, accepted success clears error, information-only recovery, existing summary invalidation |
| `Scripts/render-ui-previews.sh /tmp/codex-stats-session-previews` | 82 native synthetic previews; light/dark, five pages, warning/failure/recovery, first-failure Settings and status sheet. Parent and independent reviewer visually checked key samples; retained copies in child evidence |
| archived `accounting-repro.py --binary <current optimized CLI>` | [Independent original repro](evidence/accounting-repro.json): six explicit total oracles correct; impossible subset keeps 220 parent tokens, both child fields unknown, diagnostic present. [Assertions](evidence/accounting-assertions.txt) enforce this rather than trusting script exit0 |
| `research/differential-turns.py <corrected-pre-index CLI> <current CLI>` | [126 full JSON comparisons passed](evidence/differential-turns.json): records, identities, diagnostics, optional timings; counter Turn/time/frame/unknown-time variations, native owner/Turn variants, abort and three physical-copy modes |
| `Scripts/test-app-delivery.sh` | [18 real checks passed](../10-15-safe-local-replacement/verification.md), including runtime v1→v2 receipt, actual compile/copy/signature/identity failures, running-instance refusal, nested preflight no-write and owned preparation SIGKILL |

The independent reviewer found a transient old-bundle write during nested installer preflight. The owner reproduced it using directory mtime (a final digest alone missed it), moved preparation to independent temporary storage, and reran all 18 checks. Zero-parent subset corrections and later recovery also received explicit tests; no zero-use row or retrospective row rewrite was introduced.

Development-only setup failures are not product passes: one CLI build initially addressed flat checkpoint files as nested paths and failed before compiling that label; the corrected path compiled successfully. Child records preserve the earlier inherited-prefix fixture mistake, Swift executable/toolchain invocation errors and normalized test-path mismatch. The final logs above supersede those intermediate attempts.

## Standard fixed-input benchmark

Commands, run sequentially after all workers stopped compiling:

```sh
Scripts/benchmark-performance.sh /tmp/codex-stats-fixes-20261015/standard /tmp/codex-stats-fixes-20261015/baseline/Sources/Core baseline
Scripts/benchmark-performance.sh /tmp/codex-stats-fixes-20261015/standard Sources/Core current baseline
```

Same 349,964,213-byte synthetic fixture, 39 files, 7,020 accepted records, 9,043,780 Tokens. [Complete snapshots equal](evidence/standard-equivalence.txt): raw accounting records and order, model/session slices, day/hour buckets, diagnostics and all four periods. Controlled append restores only the generated file. No complete Turn lifecycle in this workload, so it is a scan/filter non-regression control.

| Metric | Baseline | Current |
|---|---:|---:|
| New-process scan | 2.654 s | 2.679 s |
| Unchanged-file scan | 55.32 ms | 56.09 ms |
| One-file append/reparse | 120.21 ms | 122.39 ms |
| Maximum RSS | 83.70 MiB | 83.80 MiB |
| Peak physical footprint | 59.56 MiB | 59.69 MiB |

Current filters today/7d/30d/all: 10.03/18.50/18.06/18.56 ms. These are one paired run, not a statistically demonstrated cold-scan gain. New process means empty scanner cache, not flushed OS disk cache. [Raw baseline](evidence/standard-baseline-metrics.json), [raw current](evidence/standard-current-metrics.json), separate `standard-*-memory.txt` outputs retained.

## Turn and session scaling

Same generated inputs; baseline compiles archived audit `research/scale-probe.swift` with Git baseline Core/UsageStore. Current compiles this task's probe against current Core/UsageStore, exercising the new production `sessionRows` API. Both use `xcrun swiftc -O -swift-version 5 -parse-as-library`; `/usr/bin/time -l` records process maxima. Generation script is in the archived audit task. No parallel benchmark or compile ran during measurements.

| Complete Turns in one file | Baseline warm median | Current warm median | Baseline/current cold |
|---|---:|---:|---:|
| 250 | 65.06 ms | 2.90 ms | 129.75 / 33.83 ms |
| 500 | 267.29 ms | 4.17 ms | 282.25 / 24.08 ms |
| 1,000 | 1,034.95 ms | 8.30 ms | 1,058.72 / 43.16 ms |
| 2,000 | 4,110.49 ms | 15.49 ms | 4,165.76 / 85.34 ms |

Each warm median has 3 samples. All rows, response IDs, Tokens, duration=2000ms, TTFT=100ms, output=20, responseCount=1, speed=10 tok/s and unchanged cached rows are asserted. The 2,000-Turn warm time falls about 99.6%; scale behavior is measured for this synthetic shape, not a promise for arbitrary logs.

| Session projection | Baseline median | Current median |
|---|---:|---:|
| 1,000 today | 322.65 ms | 1.22 ms |
| 1,000 all | 1.43 ms | 1.00 ms |
| 5,000 today | 1,568.90 ms | 4.58 ms |
| 5,000 all | 5.99 ms | 3.97 ms |

Five samples each, including the same final recent-activity sort. These are synchronous MainActor computation times, **not SwiftUI frame latency**. Session/model/day/hour/summary/record sums asserted throughout. Entire scale-probe process maximum RSS: 85.92→29.41MiB; peak physical footprint: 80.16→19.45MiB. This includes synthetic projection construction and summaries, not just the scanner, and is not current App memory.

[Raw baseline samples](evidence/scale-baseline.jsonl), [raw current samples](evidence/scale-current.jsonl), build and memory outputs retained alongside them.

## Native product and resources

- `Scripts/build-macos.sh /tmp/codex-stats-fixes-20261015/native`: optimized actual App built, v0.2.11/build13. [Build](evidence/native-build.txt), [validation](evidence/native-validation.txt): strict codesign, plist lint, vtool minOS14.0, otool system-framework/Swift-library dependencies only. No helper bundled in App runtime.
- `Scripts/test-app-lifecycle.sh <unique temporary identity copy>`: [PASS](evidence/app-lifecycle.txt), actual product launches through LaunchServices, duplicate exits preserving original PID, normal AppKit termination. Only that UUID's preference domain was seeded with synthetic root and then removed. No default installed identity was launched.
- `Scripts/measure-app-memory.sh <built App> <same synthetic fixture> <output>`: UUID copy; at 10s physical footprint **25.2MiB**, lifetime peak **29.8MiB**; at 35s current **26.6MiB**, lifetime peak **34.2MiB**. [Log](evidence/app-memory.txt), raw vmmap outputs in `evidence/app-memory/`. Normal termination succeeded; one sandbox-extension warning is retained. These are current/peak footprint samples, not RSS or virtual-address size. They do not prove all pages opened or identify scan completion.
- Native UI automation inventory returned a locked-Mac error and no native targets. [Exact limitation](evidence/live-ui-limitation.txt). No sheet click/Esc/search-preservation acceptance was claimed. No unlock, system preference change or user App action attempted.

## Deferred and remaining acceptance

A07 narrow layout remains deferred. No persistent cache, append parser, database, default refresh change or new feature. macOS14/Intel, VoiceOver, actual production menu/sheet/search interaction, sleep/wake and long residency remain unverified. No Developer ID/notarization, DMG or source ZIP publication. Installation helper has no in-process product readiness handshake, cross-process launch lock or power-loss durability claim. The fixture's runtime receipt proves its own live version, not a new production handshake.

Design/current baseline docs and specific specs were reconciled after validation; independent full-scope closeout review and final mechanical evidence are recorded in `check-result.md` and `evidence/closeout-checks.json`.
