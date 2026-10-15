# Independent check result

Date: 2026-10-14. Result: **PASS after two local accounting fixes**. The parent retains ownership of the independent same-pass live native oracle and final documentation/release integration.

## Reviewed scope

Compared the current source with the pre-analytics baseline tar at `/var/folders/r5/vby20fm56t3g3bhydvcn897h0000gn/T/codex-stats-before-analytics-md7xvpnb/source.tar.gz` (the root is not a Git repository). Changed source files are exactly:

- `Sources/Core/CodexLogScanner.swift`
- `Sources/Core/Models.swift`
- `Sources/Report/main.swift`
- `Tests/CodexStatsCoreTests/CodexLogScannerTests.swift`

Read the child PRD/design/implementation/context manifests, parent design, current requirements/design, existing Token display contract and both parent research documents. Reviewed physical/Session identity separation, genuine owner validation, global response conflicts, notification suppression, conservative mixed/legacy coverage, independent row identity, byte/exclusive-ordinal references and cycles, typed diagnostics and Core/CLI aggregation.

## Findings fixed

1. **Truncated copies could turn positive compaction evidence into a false response conflict.** An active log with a later `compacted` marker and a valid archived prefix just before that marker contain the same immutable response, usage, owner, Turn and timestamp. Derived `isCompaction`/context model differences previously excluded both records (110 Tokens became 0). On the parent's explicit scope decision, normalize owned native copies using positive compaction evidence before conflict validation. An unambiguous explicit payload model remains authoritative across those copies; without one, compaction stays `Unknown model`. Contradictory explicit models, actual usage, owner, Turn and time conflicts remain excluded with warnings.
2. **Global response conflicts diagnosed only the later source.** Both genuinely conflicting owners/files lose their ambiguous response, but the earlier source previously had no matching diagnostic context. Emit the same typed warning for every affected physical source/Session after establishing the conflicting identities.

Reviewer edits: the scanner fixes above, three synthetic tests, and this check record. No App/layout, timing, parser-performance, installed/running App, task state, release or Git edits.

New tests:
- `globalResponseConflictDiagnosesEveryAffectedSource`
- `laterCompactionMarkerNormalizesRetainedPrefixCopies`
- `compactionCopiesUseUnambiguousExplicitModelButRejectContradictions`

The first two tests were executed before the fixes and failed for the stated behaviors. The third checks both one explicit model against contextual inference and two contradictory explicit models.

## Exact commands and results

- `./Scripts/test.sh --filter 'globalResponseConflictDiagnosesEveryAffectedSource|laterCompactionMarkerNormalizesRetainedPrefixCopies'` before fixes: **2 tests failed**. Evidence `/tmp/accounting-check-regressions-before.log`.
- Same filtered command after fixes: **2 tests passed**. Evidence `/tmp/accounting-check-regressions-after.log`.
- `./Scripts/test.sh`: **70 tests passed, 0 failures** (67 implementation tests plus 3 reviewer regressions). Evidence `/tmp/accounting-check-tests.log`.
- `./Scripts/build-macos.sh /tmp/codex-stats-accounting-check-build`: native arm64 build and ad-hoc signing passed. Evidence `/tmp/accounting-check-build.log`. No App launch or installation was performed.
- `codesign --verify --deep --strict '/tmp/codex-stats-accounting-check-build/Codex Stats.app'`: passed.
- `xcrun vtool -show-build '/tmp/codex-stats-accounting-check-build/Codex Stats.app/Contents/MacOS/CodexStats'`: minimum deployment **14.0**, SDK 27.0. This is not macOS 14 hardware verification.
- `xcrun swiftc -O Sources/Core/*.swift /tmp/codex-stats-accounting-check/main.swift -o /tmp/codex-stats-accounting-check/check-review`: passed.
- `/tmp/codex-stats-accounting-check/check-review`: frozen **29 files / 29 sessions / 6,714 records / 890,273,713 Tokens**; global/session/model/day/hour sums and unique row identities passed; unchanged rescan cache **29/29**. Three unresolved reference diagnostics remain because this sanitized frozen corpus deliberately omits its referenced physical files. Evidence `/tmp/accounting-check-frozen.log` contains aggregate results only.

No Swift linter is configured; SPM and the native build provide compile/type checking. The pre-existing SPM CLT search-path linker warnings remain; tests and native compile are successful, not simulated.

## Remaining contract and integration notes

No further blocking defect was found in the reviewed child scope. Local expenditure includes genuinely owned native responses retained in historical physical generations, including reverted requests, and differs intentionally from current conversation projection. Mixed unidentified legacy streams remain conservative and visibly incomplete instead of being blindly unioned. A verified reference proves local boundary coverage, not additional synthesized consumption.

The parent must preserve the new positive-compaction-copy rule and all-source conflict diagnostics in its accounting spec and final project design/verification synchronization. CLI now exports typed `diagnostics`; the `warnings` projection includes warning/error messages for existing consumers, while information is available through the typed array. The later UI child must consume these types directly, without severity inference from text.

Live logs grow, so the parent's native expenditure audit must use one frozen read/same-pass oracle. This review does not claim a stable live-corpus total, real UI clicks, target-hardware acceptance, timing measurements or performance improvement.
