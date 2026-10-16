# Independent Trellis review — overview model count order

2026-10-16. Reviewer `/root/dashboard_filter_check`. Read AGENTS, the lightweight task PRD and all three check-manifest files, current reconstruction design and affected frontend/backend contracts. No per-task design.md/implement.md exists; this is the approved PRD-only lightweight task. Product sources are read-only; reviewer owns only this report. Scope is the task-start `research/before.json`, not the existing dirty workspace.

## Findings (fixed)

None required. No confirmed defect was found in the scoped change.

## Findings (not fixed)

No blocking confirmed defect. Native offscreen screenshots do not prove the actual opened popup menu's order, pointer/keyboard selection or VoiceOver behavior. These interactions, macOS 14 runtime and Intel runtime remain unexecuted; a manual check should open the menu, verify all first and descending visible counts, switch ranges, and verify the selected model stays selected even with zero records.

## Source and data-flow review

- `Sources/App/DashboardView.swift:195–199`: only the private comparator changes. Counts descend; equal counts use exact model-ID ascending comparison; missing keys are0. This strict comparator returns false for equal IDs. Models remain a deduplicated union of all-history observed IDs and the retained current selection, with no filtering of zero/missing entries.
- `Sources/App/DashboardView.swift:200–209`: the all-model Text/tag remains outside and before ForEach. Its aggregate count is unchanged; the native menu width264, labels, help and selection binding are unchanged. No selection assignment, global state, new API/cache or scan is introduced.
- `Sources/Core/OverviewIndex.swift:43–50`: modelRecordCounts is built from the accepted scalar count buckets for the requested period before applying the optional model filter. Therefore sorting correctly uses current-range counts even while a particular model is selected. `UsageStore.swift:176–184` still supplies the existing single bounded summary cache; no data-layer change is needed.
- SHA comparison against the task-start manifest confirms only DashboardView.swift changed among55 Sources/Tests/Scripts files. Replacing precisely this comparator with the original `.sorted()` recreates the task-start file SHA-256, proving there are no adjacent modifications. Core, Store, tests, scripts and other-page ordering are unchanged.
- An extra test repeating this comparator would mirror the implementation for this reversible UI change; the approved task deliberately reuses existing synthetic native overview coverage and independent source review instead. No historical test count is reported as a new execution.

## Verification

- Lint: `git diff --check` PASS; no configured standalone Swift linter. Trellis manifests validate with three real implement/check entries each.
- Independent final production typecheck: PASS, exit0 and empty diagnostics log. All55 Sources/Tests/Scripts SHA-256 values are unchanged across the check. Command uses `xcrun swiftc -O -swift-version 5 -parse-as-library -typecheck -target arm64-apple-macosx14.0`, all Core/App sources, AppKit/SwiftUI/Charts, SDK from xcrun and isolated module cache.
- Existing synthetic native overview matrix and optimized App build: root owns execution; results will be distinguished from this reviewer's typecheck and current source inspection. No redundant Core/Store full suite was run, since their hashes are unchanged.
- Reviewer evidence: `/tmp/codex-stats-overview-count-order-20261016/reviewer/` contains source-before.json, scope.txt and typecheck.log. No real logs/config, user App, commit or push was operated on.
