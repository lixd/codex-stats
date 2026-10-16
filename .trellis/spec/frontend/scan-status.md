# Shared scan status

## 1. Scope / Trigger

Read before changing dashboard refresh errors, diagnostic visibility or successful-report preservation. The shared header is the one global status destination; page-specific inherited-session warnings remain local.

## 2. Signatures

`UsageStore.scanStatus: ScanStatus` derives wording/attention from the accepted report, `hasReport`, `loading` and `errorMessage`. `ScanStatusDetails` renders the native diagnostic sheet using the existing typed `DiagnosticSummary`.

## 3. Contracts

- Retain accepted data/time and the previous error during a retry. Clear the error only when a new report is accepted or the root changes.
- Warning/error counts signal incomplete statistics on every dashboard page. Information-only history diagnostics do not become failures.
- With a successful report, use one compact header status and one scrollable 640×420 sheet. Preserve current page, filters, search and selection. Escape closes the sheet.
- First load uses `PendingUsageView`; Settings remains reachable to repair the path and keeps its error banner only before a successful report.
- Status is expressed in text and symbols, not color alone. Complete error text remains reachable. Menu B and close-before-open window ownership are unchanged.

## 4. Validation & Error Matrix

| State | Display |
|---|---|
| First load / no report | Pending, never fake zero success |
| Accepted warning/error | Visible risk count and diagnostic entry on every page |
| Failed refresh | Old data/time plus specific error, retained through retry |
| Successful recovery | New data, stale error cleared |
| Information only | Normal status with accessible details |

## 5. Good / Base / Bad Cases

Good: the overview keeps its totals after failure and exposes the real cause without navigation. Base: clean scans show normal status. Bad: a green connected label while the report contains warnings, or duplicate global banners on every page.

## 6. Tests Required

Run `Scripts/test-usage-store.sh` with real synthetic scanner success/failure/retry/recovery. Render all four pages at 950×630 in light/dark plus details; assert warning counts, information-only state and preserved successful time. Native static rendering does not prove sheet presentation/Escape or production menu clicks; record actual interactions separately.

## 7. Wrong vs Correct

Wrong: clear `errorMessage` at refresh start and classify a retained report as clean. Correct: keep the accepted report's risk/error context until a successful replacement arrives.
