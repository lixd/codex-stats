# Execution plan

1. [x] Read affected specs and approved target; confirm file ownership.
2. [x] Add meaningful regression coverage; the archived audit provides pre-fix performance evidence, and the new API's independent expected values are verified after implementation.
3. [x] Implement the smallest owned change; preserve other workers' edits.
4. [x] Run targeted checks; record failures and actual results in verification.md.
5. [x] Notify parent for serialized full-suite/build/benchmark integration and independent review.
6. [x] Finish without staging, committing, pushing, installing or archiving the task (parent handles closeout).

## Implementation boundary

A04 lives in Core date filtering and the session view projection: add an unsorted `ScanReport.sessionRows(in:now:timeZone:)` that returns session, total and models from one local bound and one per-session pass; the view owns one final user-selected sort. Date intervals also avoid per-session activity formatters. Do not cache rows or alter accounting.

A05 lives in `UsageStore` refresh state and the shared dashboard header: preserve the previous error until a successful refresh, derive shared severity from typed diagnostics, render one compact status entry and a native details sheet, and remove only duplicate global warnings from pages. Keep session-specific inherited-history warnings and all menu behavior. Tests cover date/DST/empty-active/unknown projections, real scanner failure/retry/recovery/info, and native static previews. TokenUsage and all shared design/version files belong to other workers.
