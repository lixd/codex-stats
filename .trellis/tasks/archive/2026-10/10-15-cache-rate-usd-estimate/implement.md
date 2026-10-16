# Implementation plan

Status: user authorized root self-review followed by execution; review passed.

1. Freeze product-file hashes and task-local scope before edits; load before-dev/Core/display/visual/scan-status specs. Populate final source-backed catalog tests from official pricing evidence.
2. Implement pure cache-ratio state/formatter; add independent weighted/zero/unknown tests and compact UI placements. Run focused Core/formatter and native two-palette fit checks before starting cost work.
3. Implement fixed catalog + Decimal per-accepted-record estimate accumulator with total/model/session summaries, explicit missing reasons/coverage. Hand-calculated fixtures must include zero, output-only, partial cache, missing/unknown model, micro-USD, huge values and rounding boundaries. Keep original accounting unchanged.
4. Integrate off-main session/day/model scalar index atomically paired with report, current-range UsageSummary, details, read-only catalog explanation and CLI shared output. Verify report refresh failure/range/date/palette transitions and equal cross-page/CLI values under fixed now.
5. Render menu + analysis at288/950/1120, cyan/blue light/dark, legacy/overlay, long names/large values/unknown/partial states; inspect model A hierarchy and no horizontal overflow. Preserve search/sort/selections.
6. Run Scripts/test.sh, test-token-display.sh, test-usage-store.sh, render-ui-previews.sh plus App/CLI typecheck/build/signature verification. If tests need new formatter harness input, extend existing harness, do not introduce dependencies. Measure synthetic aggregation cost on fixed input; no unsupported speed/memory claims.
7. Independent trellis-check review, fix only task defects. Update docs/VERIFICATION and baseline only after passing checks. Deliver independent /tmp App and current-source zip; archive/journal with --no-commit. No user App operations, commits or pushes.

Risky files: Sources/Core new calculator/catalog, Sources/App/UsageStore.swift, Components.swift, MenuPanelView.swift, DashboardView.swift (overview/model only), SessionsContent.swift (details/settings), RequestsContent.swift (details only), Sources/Report/main.swift, affected synthetic tests and Assets/Info.plist at delivery. Product changes outside these require an explicit scope reason; Scanner and request Table remain untouched.
