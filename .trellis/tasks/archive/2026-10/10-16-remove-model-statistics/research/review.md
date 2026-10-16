# Independent Trellis review — R22

2026-10-16. Reviewer `/root/dashboard_filter_check`. Read the task PRD/design/implementation plan, all four check-manifest entries and the approved formal design. Review scope is the current task's `research/before.json`, not the larger pre-existing dirty workspace. Product files were read-only; this reviewer owns only this report. No user App, real logs or real price file were operated on.

## Findings (fixed)

None required. The deletion is surgical and no additional confirmed defect was found.

## Findings (not fixed)

No blocking confirmed defect remains. Native screenshots and programmatic AppKit tests do not establish actual pointer navigation, keyboard/VoiceOver behavior or long-running reliability. Those actions, macOS 14 runtime and Intel runtime were not performed in this review. Historical model-page documents/evidence can remain historical, but current baseline/spec descriptions must reflect the four-page contract during root's closeout.

## Scope and behavior evidence

- `Sources/App/DashboardView.swift`: direct comparison against the reviewer's captured task-start copy shows exactly the model enum case, icon and switch route removed, together with `ModelsContent` and `ModelUsageGroup` and their private search/sort/format helpers. No hidden/disabled replacement route or compatibility state was added. The default is still overview and the sidebar iterates the remaining four enum cases.
- Task-start SHA comparison shows no changes to Core, UsageStore, RequestsContent, SessionsContent, PriceManagementContent, shared Components/ModelBar, palette roles, CLI, lifecycle or data tests. Their retained model capabilities are not dependent on the removed private page.
- The overview still consumes the same filtered scalar summary for four cards, chart, distribution and Token details, with the existing request handoff. Session-level model lists/costs and settings price management retain their existing files and routes.
- A repository search over current `Sources`, `Tests`, `Scripts` finds no `ModelsContent`, `ModelUsageGroup`, `DashboardSection.models`, model navigation case, `expectedModelRows` or `--legacy-models` references. Unrelated `.models` aggregate fields correctly remain.
- `Tests/UIPreview/main.swift`: obsolete model-page captures, search-state branches, model-only long-name fixture and model geometry checks are removed. The retained synthetic80-record request fixture still verifies native Table width/column count and last-row reach. Model valuation dictionary assertions remain; valuation presentation now renders the actual overview, session and settings pages. Request/session search, request selection/sheet, settings draft, palette retention, menu and shared diagnostic/recovery coverage remain.
- `Scripts/render-ui-previews.sh`: removes the obsolete model-only startup child invocation. Existing request legacy geometry tests remain inside the shared harness; the dedicated overview matrix separately owns startup legacy-scrollbar verification.

## Native evidence inspected

Read four current950 light warning-state PNGs under `/tmp/codex-stats-remove-model-statistics-20261016/ui-cyan`: `status-warning-square.grid.2x2-light.png`, `status-warning-list.bullet.rectangle-light.png`, `status-warning-rectangle.stack-light.png`, `status-warning-gearshape-light.png`. All show exactly the four remaining navigation items and an intact diagnostic header. Overview retains the model selector/distribution, requests retain the native table/filter, sessions retain model details, and settings retain the reference-price section. No horizontal clipping was observed in these representative images; vertical scrolling remains intentional.

The current request geometry log shows, for example, document733pt/clip733pt at950 and retains seven columns plus failure/recovery variants. This is actual native geometry, not an assertion inferred from requested column widths. Root's current dedicated overview matrix reports all four palette/startup-scroller processes passing. Its cyan950 partial document/clip widths are765/765pt; blue startup-legacy950 long-name widths are748/748pt. The reviewer also inspected that final dark long-name PNG: the four-item sidebar and complete overview remain readable without horizontal expansion.

## Verification

- Lint: `git diff --check` and `bash -n Scripts/render-ui-previews.sh` pass. No separate Swift linter is configured.
- Trellis context validation: pass, four real implement/check entries each.
- TypeCheck: PASS. Reviewer independently executed the final frozen-source production Core+App frontend check with `-O -swift-version 5 -parse-as-library -typecheck -target arm64-apple-macosx14.0`, AppKit/SwiftUI/Charts and an isolated module cache; exit0 and no diagnostics. Before/after SHA-256 comparison passes for all55 Sources/Tests/Scripts files, and exactly the three scoped files differ from task start. Evidence is `/tmp/codex-stats-remove-models-20261016/reviewer/{typecheck.log,checks.txt,source-before.json,source-after.json}`. Root owns the separate final optimized executable/signature gate.
- Tests: reviewed both current cyan and blue full UI logs: exit0/PASS, each149 PNG/35 TXT, covering the four pages, palette/state retention,80-record request scrolling, valuation, menu and diagnostics. Root's dedicated overview four-process matrix also reports PASS. These harnesses were executed by the implementer/root; the independent reviewer inspected their current outputs and representative images. Core/Store full suites were intentionally not duplicated for this deletion; task-start hashes establish those source/tests are unchanged. Do not present the preceding task's145 Core tests as a new R22 execution.
