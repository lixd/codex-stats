# Independent R20/T14 review

2026-10-15. Reviewed the active task PRD/design/implementation plan, approved project design, applicable backend/frontend contracts and actual Sources → Store → native UI / Report paths. Compared scope against `implementation-before.json`; Scanner, Models, accounting and lifecycle source hashes remain unchanged by this task. Existing unrelated dirty changes were preserved. No installed App, real logs, real price configuration, commit or push was used.

## Findings (fixed)

1. **Historical built-in provenance could claim today's verification date.** `Sources/App/Components.swift:124` previously used `ReferencePricing.verifiedOn` for every saved built-in snapshot, although `PriceCatalog` intentionally preserves historical prices/dates. The implementer removed the fixed date claim: help now identifies the effective revision and provenance category and directs users to the saved rows' source/date. `Tests/TokenDisplay/main.swift` includes a 2025 built-in snapshot with an explicit assertion that its help does not claim the current compiled verification date. Confirmed source correction; three-locale formatter run passed.
2. **Empty CLI sessions could claim the old compiled price revision.** Scanner retains metadata-only sessions. The zero-record fallback in `Sources/Report/main.swift:72` used a default `CostEstimate()`, which reports the compiled revision even after loading another catalog. CLI and native empty-group fallbacks now carry the effective catalog/snapshot revision. Root will include the metadata-only session in its final CLI oracle; the original nonempty fixture alone did not exercise this case.
3. **Unavailable configuration was described as fully priced.** In the first native error screenshot, a failed configuration read (`catalog == nil`) produced an empty candidate array and the misleading message “所有已识别模型均已配置价格”. `Sources/App/PriceManagementContent.swift:61` now explicitly says candidates cannot be determined until configuration recovery. Independently inspected the regenerated `ui-verified/cyan/unavailable-950-light.png`: the corrected message is visible alongside the concrete error and retry action.

Fixes above were coordinated with the implementer while it owned product files, avoiding concurrent edits. The reviewer changed this report only.

## Findings (not fixed)

No outstanding confirmed product defect found in this review.

One small implementation/design discrepancy was explicitly resolved with the main session: the accepted-model set is cached in `ScanSnapshot`, while candidates perform a small set subtraction/sort on read. The main session agreed to describe this bounded model-set work accurately rather than add another cache lifecycle. It does not traverse records or scan disk; this is not a measured performance defect or a performance improvement claim.

Actual pointer-driven management navigation, native dropdown selection, Save/Cancel/Escape sheet interaction, VoiceOver, system increased contrast, Intel and macOS 14 runtime remain manual checks. The compiler target establishes macOS 14 API compatibility only. Static form renders and programmatic NSTextField edits are not proof of these interactions.

## Data/state review

- `PriceCatalog.swift` validates exact, nonnegative decimal strings on both construction and decode; retains real zero, rejects partial parsing/overflow/underflow, duplicates and unknown identity. The immutable parsed `ReferencePrice` is cached once per catalog row; JSON keeps strings and source metadata.
- `PriceCatalogFile.load/save` persists the complete effective schema/revision/row snapshot atomically. Only missing files use defaults. Saved empty catalogs and deleted built-ins do not merge defaults back on restart. Read/save errors remain observable.
- `ScanSnapshot.observedModels` derives from all accepted historical records. Candidates subtract priced IDs and exclude `Unknown model`; time range does not restrict candidates. Both built-in and custom deletion use the same `deletePriceBlockReason` gate, including existing records, pending/failed scans and non-information diagnostics; the action rechecks the gate. Tests now exercise actual damaged-row warnings and duplicate-history information-only reports.
- Store serializes file I/O, scans and valuation on one worker. Saves persist before publishing a new catalog; failed saves keep the old catalog/summary. `valued` checks captured revision and `revalueCurrentReport` checks report generation before replacing the report/valuation pair. Price operations do not call Scanner. Request detail estimates use the paired snapshot catalog. No new Timer or network path was added.
- Current prices apply uniformly to history. Record-level missing-cache/missing-price coverage and exact Decimal arithmetic remain explicit; Token counters are unchanged. Custom values are visibly distinguished from built-in references. CLI reads the same file reader and exposes the effective catalog; it has no price write action.

## Verification

- Lint equivalents: `bash -n` on affected check/render scripts and `git diff --check` passed. The project has no configured separate Swift linter.
- Independent TypeCheck: first optimized `arm64-apple-macosx14.0` type-check passed with no diagnostics. Final rerun after the implementer's parsed-price caching change also passed (exit 0, no diagnostics); every Sources/*.swift hash was unchanged through that final run. Log: `review/typecheck-macos14-final.log`; source manifest: `review/reviewed-source-sha256.json`.
- Core: main session's current `validation/core-host-final.log` shows 142 tests passing. The reviewer did not start another full test runner. Main session owns final rerun after any Core change.
- Store: `store-verified.log` passed all-history candidate/typed deletion parity, actual warning/information gating, add/edit/zero validation, save retention, persistent deletion, no-rescan and scan/edit convergence checks.
- Formatter: `display-final.log` passed the actual App formatting in en_US, zh_CN and fr_FR, including historical provenance.
- CLI: inspected root's `validation/cli-oracle.json`: baseline `$0.00686625`, add `$0.01280625`, override `$0.01428625`; empty catalog unavailable/null; 5,700 Token invariant and all record/model/session hierarchy sums. Invalid file/missing `--prices` value/unknown argument all fail on stderr. Root owns final binary rebuild and empty-session revision assertion.
- Native: read actual current matrix logs and inspected 950-light management, dark long-model edit, light add and regenerated error PNGs. `ui-verified.log` passes cyan/blue × light/dark × 950/1120 plus native legacy-scroller processes, document-width ≤ clip-width, editable field bindings, no-candidate/error states and persisted add without scan. Forms are production views hosted offscreen; not a live installed-App interaction test.
- General native regression logs cover existing menu/model/request geometry, request sheet attachment and 80-record scrolling; no user App was operated. Exact final deliverable build/signature/version/package verification belongs to the main session.

Evidence directory: `/tmp/codex-stats-price-management-20261015/`. Independent check logs and reviewed source SHA256 manifest are under `review/`.
