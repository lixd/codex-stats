# A04 / A05 implementation verification

## Scope and implementation

- `ScanReport.sessionRows(in:now:timeZone:)` returns unsorted `SessionUsageRow` values with session, range total and model details. One operation-local Gregorian boundary is reused for all sessions; start/end `Date` comparisons preserve active empty sessions without formatting their dates. The App filters these rows and sorts once using the chosen order.
- The dashboard has one compact status row for every page after a successful scan, with warning/error counts, retained-data refresh failures, complete error help, and a native 640×420 details sheet. The sheet reuses grouped typed diagnostics, scrolls, and supplies an Escape close shortcut. Sidebar status now reflects statistical risks rather than only root-read errors.
- `UsageStore` preserves the prior failure during a retry and clears it only when a new report is accepted. Accepted report/time and warnings remain visible while refreshing. Information-only diagnostics are normal, not warning state.
- Removed duplicate global diagnostic/error sections in overview, requests and settings. Settings retains its error banner **only before any successful report**, because it is intentionally available instead of `PendingUsageView` so users can repair the path. Session-specific inherited-history warnings remain.
- No product version/design/spec edits, user App operations, real-log mutation, installations, commits or pushes performed by this child task. Other workers own accounting and delivery changes.

## Verification status

Focused tests and native previews pass. Parent owns final serialized benchmarks, full integration and independent review; this child verification does not establish the overall quality gate.

| Command | Current result |
|---|---|
| `Scripts/test.sh --filter 'sessionProjection\|operationBounds'` | 4 tests passed; [output](evidence/date-tests.txt) |
| `Scripts/test-usage-store.sh` | Real scanner/store state assertions passed; [output](evidence/store-tests.txt) |
| `Scripts/render-ui-previews.sh /tmp/codex-stats-session-previews` | Passed; 82 native PNGs including all five pages at 950×630 in three diagnostic states and both themes; [output](evidence/native-previews.txt) |
| `git diff --check` | Passed after implementation |

- Added explicit date/DST fixtures for 23/25-hour days, midnight invalidation, bounded future exclusion, 7/30/all windows, timezone snapshots, active empty sessions, input order, per-model sums and unknown-field flags.
- Extended real scanner/store harness for warning retention, failure/retry, success recovery to information-only diagnostics, and truthful first-loading state. No mocked successful scan.
- Extended native preview harness to render all five pages at 950×630 in light/dark under actual warning, failed-refresh retained-report and recovered info-only states; 640×420 sheet content is also captured. Only a generated UUID temporary root is deleted/recreated for failure simulation.
- Initial command setup errors: bare `swift` resolves to an unrelated OpenStack CLI on this host; direct `xcrun swift test` omits the Testing macro plugin. Use the repository's `Scripts/test.sh` wrapper, which supplies the bundled macro path. These are tooling failures, not passed test results.

## Native layout inspection

Inspected the warning model page, retained-report failed session page, light/dark sheet content, recovered information-only model page and first-failure Settings page. Status text and details entry remain readable; retained report still displays 110 Token and the previous successful time. The pre-existing horizontal table overflow at 950pt remains A07's deferred scope. First-failure Settings preserves its error in the existing scrollable scan-status section.

The first direct sheet-content preview lacked the window background provided by actual native presentation. The preview host was corrected to use `CPTheme.viewBackground`; the full renderer was then rerun successfully. This was a screenshot-host fix, not a product failure or substituted test data.

- [Model warnings, light](evidence/status-warning-cpu-light.png)
- [Session warnings, dark](evidence/status-warning-rectangle.stack-dark.png)
- [Failed-refresh models, light](evidence/status-failed-refresh-cpu-light.png)
- [Failed-refresh sessions, dark](evidence/status-failed-refresh-rectangle.stack-dark.png)
- [Failed-refresh sheet content, light](evidence/status-sheet-failed-refresh-light.png)
- [Warning sheet content, dark](evidence/status-sheet-warning-dark.png)
- [Information-only recovery, light](evidence/status-recovered-info-cpu-light.png)
- [First-failure Settings, light](evidence/error-settings-light.png)

## Files changed

`Sources/Core/Models.swift` (session/date/report sections only); `Sources/App/UsageStore.swift`, `DashboardView.swift`, `SessionsContent.swift`, `RequestsContent.swift`, `Components.swift`; `Tests/CodexStatsCoreTests/DateFilteringTests.swift`, `Tests/UsageStore/main.swift`, `Tests/UIPreview/main.swift`; this task's execution notes/evidence. `DiagnosticSummary`'s compact mode was removed after its only consumer was replaced by the shared sheet; the standard grouped view remains.

## Boundaries

Static native images verify layout and content only. Actual menu clicks, native sheet presentation/Escape, retained selection/search and VoiceOver are not established by screenshots. Parent may add isolated interaction evidence. No performance gain is claimed until parent runs controlled old/new benchmarks.


## Final integration handoff

Parent completed the final 133-test suite, 126-case differential, fixed-input accounting/scale verification, optimized native build, isolated lifecycle and App footprint checks. See [integration evidence](../10-15-small-beautiful-fixes/verification.md). Child-local statements that parent integration was pending describe the earlier handoff. Native clicks/Esc remain explicitly unverified because the Mac is locked. No production App operation or commit occurred.
