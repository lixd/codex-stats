# Final verification — dashboard model filtering (R21/T15)

2026-10-15; v0.2.18/build20. Host macOS27.0.1/26A434, arm64, Apple Swift6.4. Product targets macOS14+. The pre-existing dirty workspace was preserved; no commits/push or production App installation/launch/quit/replacement, real log/config changes, runtime dependencies or network calls were introduced.

## Current execution

- `Scripts/test.sh`: host runner exit0, **145 tests passed**. `core-frozen.log` is this round's actual execution, not prior142 evidence. Scanner/Models/lifecycle hashes are unchanged from task-start.
- `Scripts/test-usage-store.sh`: pass, `store-final.log`; exact-model/range/zero/count summaries, bounded object reuse, palette reuse/menu isolation, price invalidation, explicit import preserving custom/deleted rows, persistence and failed save; filter/import/edit does not rescan or alter scan-success time.
- `Scripts/test-token-display.sh`: pass en_US/zh_CN/fr_FR.
- `Scripts/render-ui-previews.sh … cyan` and `… blue`: both pass existing page/state/geometry matrices. Final changed overview/price views were rerendered after the final amount-width change below; no other Sources/Tests/Scripts edits followed freeze.
- `Scripts/render-overview.sh …/overview-final`: exit0, all4palette/startup-scroller processes pass,2widths×2schemes; known/partial/unpriced/long/empty/unknown-cache/large-money/retained-failure, actual document<=clip. Fixture4040M exactly equals hourlySum4,040,000,000 over40accepted records. Existing request Table gets8rows for injected selected model. Vertical scrolling is expected.
- `Scripts/render-price-management.sh …/price-ui-final`: exit0, all4processes pass; saved old catalog shows named import prompt, successful import preserves scan time and removes prompt; production add/edit text bindings, protection, candidate and geometry checks.
- Independent fixed hand oracle: `oracle/expected.json` was written before implementation, eight scanner fixtures, fixed2026-10-15T16:00+08, zoneAsia/Shanghai. `oracle/main.swift` compiled from frozen productionCore with `-O`, sixcases match exactUSD/coverage/count/day/hour sums via `oracle/check.py`. All5550Token, USD0.0113 estimated4910Token/unknown640; today4120Token, USD0.00758; sol6all3060Token/USD0.00528; sol6today1630/USD0.00156; sol56all2060/USD0.0056; auto-review110Token/no amount. CLI `.build/debug/codex-stats-report INPUT --prices NONEXISTENT_TEMP_PATH --records` matches all-model overview including coverage and eightrecords. No user price file is read.
- Independent Trellis checker: source/dataflow/UI review, separate macOS14-target frontend typecheck exit0/no diagnostics,55source/script/test hashes unchanged; `research/review.md`. No blocking confirmed defect remains. Original six manifest entries plus the new overview-query contract validate (7each).
- `Scripts/build-macos.sh /tmp/codex-stats-dashboard-filter-20261015/native`: optimizedarm64 App built successfully; CFBundleShortVersionString0.2.18/build20, minimum14.0, strictdeep codesign verification pass. `otool -L` contains system frameworks/libraries only.57build inputs unchanged before/after; details in build-integrity.json. App executableSHA25631058b98219941c24b7d77d13b0d45ab7b026e5631049f02e11b04491e24ec2d.
- `git diff --check`: pass. Price sources verified from official pricing page and2026-09-22changelog; see pricing.md. codex-auto-review remains unpriced by explicit userdecision.

## Reproduce the independent oracle

From repo root, compile Sources/Core/*.swift plus this directory's oracle/main.swift with `xcrun swiftc -O -swift-version 5 -parse-as-library … -o /tmp/overview-oracle`. Run that executable with the oracle/input directory as its sole argument, writing oracle/output.json. Run the Report CLI with the same input and a dedicated missing temporary --prices path, write oracle/report-cli.json, then `python3 oracle/check.py`. Preserve the predeclared expected.json; never point this harness at real logs.

## Evidence limits and manual acceptance

Offscreen native geometry, seeded model state, programmatic text editing and typecheck do not prove pointer-selected dropdowns, view-record button clicking, actual menu/window interactions, VoiceOver, system increased contrast, Intel or macOS14runtime. No long-duration memory/footprint/wakeup or latency benchmark was performed this round; bounded indices/cache and no query rescans are implementation/test facts, not measured whole-App resource savings. Signing is local ad-hoc, not DeveloperID/notarization. Test hosts use temporary files and isolated defaults. Previously working real App remains untouched.

Manual next checks: open the independent build yourself; choose sol6/sol56/all and today/7d/30d/all, compare cards/trend/details; enter request records and verify carried model; switch cyan/blue and resize950/1120; on a previously saved table click Settings→Manageprices→补充新增内置价 and verify existing custom rows persist, auto-review remains unpriced; try keyboard and VoiceOver.
