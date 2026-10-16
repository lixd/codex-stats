# Independent Trellis review — R21/T15

2026-10-15. Reviewer: `/root/dashboard_filter_check`. Scope is this task's changes relative to `implementation-before.json`, not the repository's larger pre-existing dirty diff. Read the PRD/design/implementation plan, all six check-manifest entries, backend/frontend indexes and the new `overview-query.md` contract. No user logs/configuration or running product App were used. The reviewer changed only this report.

## Findings (fixed)

No product changes were made by this reviewer. No additional confirmed implementation defect was found in the reviewed Core, Store, overview, request handoff or explicit price-import paths.

The implementer separately found that a very large custom-price result could split digits across lines at950. Its final fix uses intrinsic single-line `ViewThatFits` candidates at26/17pt and a readable17pt multiline last candidate for truly extreme values, preserving exact help/accessibilityValue. The reviewer checked the actual final950 light PNG showing `$80,000,800.00` as one readable line; ordinary card values remain26pt. This was the implementer's finding/fix, independently verified here.

## Findings (not fixed)

No confirmed defect or blocking product decision remains from this review. The following are evidence limits, not claimed defects:

- Native pointer selection of the model Picker and clicking the overview-to-request action remain manual. Source connects the selected model to the existing RequestsContent initial filter; the isolated production-view host verifies eight actual native Table rows for that model. This does not prove a mouse click completed.
- Real VoiceOver, system increased-contrast switching, macOS 14 runtime and Intel execution were not performed. The compiled minimum target, accessible labels/help and resolved color contrast do not replace those checks.
- The query/cache review establishes bounded retained summaries and no record pricing/scanning in the filter path. It is not a whole-App memory, long-running wakeup or cold-scan performance measurement.

## Review evidence

- `Sources/Core/OverviewIndex.swift:23`: accepted daily/model rows supply Token totals; accepted records supply counts and absolute-hour scalar buckets. Queries apply one range bound and an exact optional model, preserve unfiltered per-model dropdown counts and do not retain a second records array. DST-hour iteration uses absolute Date identities, preserving repeated local hours.
- `Sources/Core/UsageValuation.swift`: the existing checked Decimal buckets receive the same model/day filter; missing price/cache and coverage semantics are preserved. `codex-auto-review` is not aliased to another model or assigned zero pricing.
- `Sources/App/UsageStore.swift:176`: one overview cache is separate from the original unfiltered menu/other-page cache. Both invalidate in snapshot didSet, including repricing; usage and money share captured now/timezone. Queries do not call scanner, timer configuration or update successful-refresh time.
- `Sources/App/DashboardView.swift:196`: all-history model choices show current-range counts and retain an absent selected model. Card/trend/distribution/details use the same overview result. Long exact model ID remains available in help/accessibilityValue.
- `Sources/Core/PriceCatalog.swift:99`: explicit import adds only missing members of the two new built-ins. Existing complete/empty files do not merge defaults, existing custom values remain unchanged, and prior deleted old built-ins remain absent. Persistence/error pairing uses the existing Store operation.
- `Sources/App/PriceManagementContent.swift`: built-in rows display their actual sourceURL and verification date. gpt-5.6-sol's promotional reference and stated minimum duration remain visible. The explicit import banner names the missing models and does not promise a runtime price service.
- Independently inspected production native PNGs under `/tmp/codex-stats-dashboard-filter-20261015/overview`: cyan all-partial 950 light; blue priced 1120 light; cyan startup-legacy long-name 950 dark. Four cards, unestimated coverage wording, chart and detail hierarchy are readable; the long Picker title truncates without widening the layout. Actual paired geometry files show document width <= clip width. Vertical scrolling is intentional.
- Inspected final rerendered partial and large-dollar PNGs in `overview-final/cyan`, and pre/post explicit import PNGs in `price-ui-final/cyan`. The import notice aligns with the catalog rows, names both missing models and displays the promo limitation; it disappears after a successful import. All four final overview and four price palette/scroller processes report PASS in `overview-final.log` and `price-ui-final.log`.
- Root's independent fixed eight-record hand oracle was cross-checked against its predeclared expected values: all USD 0.0113/5550 Token; today USD 0.00758/4120; gpt-6-sol all 0.00528/3060 and today 0.00156/1630; gpt-5.6-sol 0.0056/2060; auto-review null/110. Coverage counts and date/hour sums agree. This oracle was executed by root, not represented as a second reviewer execution.

## Verification

- Lint: `git diff --check` and `bash -n Scripts/render-overview.sh` pass; the project has no separate configured Swift linter.
- Context: task validate passes, six real implement and six real check entries.
- TypeCheck: PASS, reviewer independently executed `xcrun swiftc -O -swift-version 5 -parse-as-library -typecheck -target arm64-apple-macosx14.0` over all production Core/App sources with AppKit/SwiftUI/Charts and an isolated module cache. Exit0, no compiler diagnostics. Evidence: `/tmp/codex-stats-dashboard-filter-20261015/reviewer/typecheck.log` and `checks.txt`. The55 frozen Sources/Tests/Scripts hashes captured around compile completion remain unchanged (`source-before.json`/`source-after.json`). No claim that typecheck itself performs optimized code generation; root owns the final executable build/signature check.
- Tests: PASS, root's final host Core log `validation/core-frozen.log` reports145 tests; reviewer read that result rather than starting a duplicate runner. Implementation agent's Store log reports model/range/count/zero, bounded identity, menu isolation, import preservation, failed-save retention and no-rescan checks passing. Final native overview/price matrices pass for both palettes, schemes and actual startup legacy geometry; full UI cyan/blue logs also report palette-role/contrast, state-retention and original pages passing. These are this task's current logs, not historical v0.2.17 results. Full final command inventory remains root's verification record.
