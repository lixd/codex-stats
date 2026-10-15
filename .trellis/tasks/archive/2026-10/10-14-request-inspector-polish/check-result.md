# Final independent check

**PASS after four cross-copy timing/coverage regressions were fixed.** No remaining source defect was found in the approved scope. Installed-app interaction and macOS 14 runtime acceptance remain unverified and must not be described as passing.

## Scope and contracts

Loaded the dispatched check skill/agent protocol, task PRD/design/context manifests and all referenced requirements, design, research and frontend/backend accounting/performance/Turn contracts. Compared Sources with `/tmp/codex-stats-after-performance/Sources` and with the original approved `source.tar.gz`, extracted under `/tmp/codex-stats-inspector-check-original`. This workspace has no Git repository; no Git initialization or commit was performed.

Reviewed Core, CLI, App, tests and scripts across the parent scope. The current child adds Turn metadata and native inspector/diagnostic/display presentation. The earlier accounting and optimized timestamp/day-bound/filter/store logic remains intact. CLI integer accounting and typed diagnostics continue to use Core; optional Turn metadata is encoded through the shared record model. No request-duration estimator, cost/provider/network feature or auth/config read was added.

Verified source paths for explicit native owner/Turn association, whole-physical-history response deduplication, genuine conflict exclusion, abort/error handling, repeated completions, zero versus missing TTFT, unsupported legacy/inferred/foreign membership, incomplete/corrupt/history coverage and full-Turn numerator independent of date/model/search filtering. Duration is a validated explicit field rather than timestamp subtraction. Valid recorded timing can remain known while output/count/rate are unknown.

UI uses shared K/M with exact help for remaining menu/card/session/list captions; unknown fields are not zero. Typed diagnostics retain every message/file in severity/type groups. Request projections preserve one sort, and the first-load/refresh/root-state behavior retains the verified Store contract. The native Table owns scrolling and retains the leftmost timestamp at default 1120 and minimum 950 dashboard widths. The inspector has close/Escape handlers and does not recreate search/model/sort controls when selection closes. These source and static-render observations do not prove actual user actions or scroll-position preservation.

## Findings fixed

Changed only `Sources/Core/CodexLogScanner.swift` and `Tests/CodexStatsCoreTests/TurnPerformanceTests.swift` during independent check:

1. Invalid same-Turn completion duration/TTFT in another physical copy was ignored, allowing an otherwise complete copy to supply success timing. Invalid duration/TTFT now records failed Turn evidence; all copies are considered before attaching timing. The regression exercises zero duration, excessive TTFT and malformed TTFT.
2. A second copy's unidentified native response inside the complete Turn interval could be omitted from the observed Turn set, leaving a false mean. Every candidate interval must be locally complete, and unassigned native responses in any copy within the interval deny coverage. The regression covers copies with and without lifecycle metadata; the legal timer stays known, while the unidentified response never acquires membership.
3. An unassigned native response with missing timestamp could not be proved outside the interval, yet previously allowed a mean. Missing time now conservatively denies coverage. The accepted response retains its legal timer and no output/count/rate is invented.
4. A cumulative frame in another physical copy, conservatively excluded by accounting, could be absent from the selected candidate's pairing check and leave a false mean. Pairing checks now inspect every physical copy's Turn/range/time-relevant cumulative frames, including missing-time evidence. Excluded expenditure is not treated as proof of complete performance coverage. Token accounting remains unchanged.

The first two tests failed before repair with four assertion issues (`/tmp/inspector-check-regression-before.log`); the latter two failed before repair with two issues (`/tmp/inspector-check-coverage-before.log`). All pass after the fixes. Root explicitly confirmed these repairs fall within the approved accuracy/Turn contract. The final root-authored Turn spec accurately records the new cross-copy coverage checks.

## Executed verification

| Command | Result / evidence |
| --- | --- |
| `./Scripts/test.sh --filter 'invalidCompletionInPhysicalCopy\|UnidentifiedTurnResponseInCompletePhysicalCopy'` | Before-fix failure: 2 tests / 4 issues; `/tmp/inspector-check-regression-before.log` |
| `./Scripts/test.sh --filter 'invalidCompletionInPhysicalCopy\|unidentifiedTurnResponseInPhysicalCopies'` | PASS after first repairs; `/tmp/inspector-check-regression-after.log` |
| `./Scripts/test.sh --filter 'unknownTurnAndTimestamp\|excludedPhysicalCumulative'` | Before-fix failure: 2 tests / 2 issues; `/tmp/inspector-check-coverage-before.log` |
| `./Scripts/test.sh --filter 'unknownTurnAndTimestamp\|excludedPhysicalCumulative\|completeTurnUsesWhole\|unattributedCumulative'` | PASS: 4 focused tests; `/tmp/inspector-check-coverage-after.log` |
| `./Scripts/test.sh` | Final PASS: **100 tests / 0 failures**; `/tmp/inspector-check-core-final.log` |
| `./Scripts/test-token-display.sh` | PASS: 16 boundaries each in en_US / zh_CN / fr_FR; `/tmp/inspector-check-display-final.log` |
| `./Scripts/test-usage-store.sh` | PASS: real scanner pending/refresh/failure/root reset/empty/obsolete-result states; `/tmp/inspector-check-store-final.log` |
| `bash -n Scripts/*.sh` | PASS: all shell scripts |
| `./Scripts/build-macos.sh /tmp/codex-stats-inspector-check-build` | Final PASS after all repairs; `/tmp/inspector-check-native-final.log` |
| `codesign --verify --deep --strict --verbose=2 '/tmp/codex-stats-inspector-check-build/Codex Stats.app'` | PASS: valid on disk, designated requirement satisfied |
| `xcrun vtool -show-build '/tmp/codex-stats-inspector-check-build/Codex Stats.app/Contents/MacOS/CodexStats'` | Native arm64 binary, `minos 14.0`, SDK 27 |
| `./Scripts/render-ui-previews.sh /tmp/codex-stats-inspector-previews` | Final PASS: 26 native PNGs; `/tmp/inspector-check-previews-final.log` |

There is no configured standalone Swift linter. Compilation supplies native type checking; shell syntax, formatter and automated behavioral tests are separate checks. Native builds were done on the current Apple Silicon/macOS 27.0.1 host and were not installed or launched as the user's application.

## Preview evidence and acceptance boundary

Inspected all 26 supplied light/dark images: today/seven-day overview, menu, request tables and inspectors at 1120/950, known/unknown Turn details, grouped diagnostics, pending, successful empty and missing-root error. After the final Core repairs, regenerated all 26 using the isolated UserDefaults suite and synthetic logs, validated PNG count/headers/dimensions and reinspected known timing, 950 dark inspector, menu and error captures. The known synthetic Turn remains 120 s / 2 s TTFT / 3,600 output / 30 tok/s; the request itself remains —. Unknown timing remains —. Information groups use an information icon; real warnings remain visible. Menu exit is conspicuous, and missing initial results are not rendered as successful zero.

At narrow widths or with the inspector open, later Table columns require native horizontal scrolling; timestamp remains visible. The inspector's vertically scrollable content extends below the viewport. Static images cannot validate these scroll gestures, row clicks, Escape/close, clipboard actions, search/filter/sort interaction or retained scroll positions. The failed offscreen AX/programmatic-action experiment was removed from source and is not counted as a pass. No UI automation retries or fabricated action proof were used here.

The earlier independent accounting/performance gates remain evidence for their respective scopes. This check did not rerun or publish concurrent-compilation performance numbers; parent performs the final serialized benchmark and independent CLI/native corpus audit. Parent also owns docs/release/DMG/lifecycle/package and task archival. No parent docs, versions, dist artifacts, installed applications or real logs were changed by this checker.
