# Technical design

Status: implemented and verified v0.2.16/build18 after root plan review. User approved API-equivalent USD semantics, not actual billing. Canonical implemented contract: [cache-rate-cost-design](../../../../../docs/cache-rate-cost-design.md), sections 2–6. Task-start baseline was v0.2.15/build17; actual gates and remaining manual acceptance are in research/verification.md.

## Boundaries

Pure Core derived calculator + fixed reference price catalog; Scanner/dedup/model attribution unchanged. Feed only accepted records, same date bounds and captured now. Decimal arithmetic and explicit full/partial/unavailable states; sum estimates before rounding. Cache ratio derives from TokenUsage knownness. Partial cost coverage must retain known records even within an incomplete aggregate model slice.

## Integration

ScanWorker builds a scalar session/day/model valuation index off-main after scan, accepting it atomically with its matching report. UsageSummary merges index buckets for the current range; no per-record Decimal work in main-thread summaries, retained record copies or new persistent cache. Failed/old-root refresh cannot publish mismatched index/report. Session detail reads cached estimates, not sort-comparator recomputation. Request estimates use accepted record usage only. CLI shares Core results and exposes precise decimal strings, state, coverage and catalog version. Canonical UI table defines menu/overview/model/details/settings placements; request table geometry is unchanged.

## Catalog and compatibility

Fixed Standard short-context input/cache/output reference, same snapshot for all historical usage. Exact IDs only; no guessed aliases or account reads. Omitted charge dimensions are visible assumptions, not fallback recovery. Baseline prices and official sources in research/pricing.md; never imply a current or historical actual bill. Existing CLI Token fields remain; additive derived output has explicit currency/version and typed state.

## Risks and rollback

Unknown cache may affect partial coverage; test per-record coverage rather than whole-model exclusion. Prevent Decimal -> Double money calculation, formatter rounding before sum and UI body scans. Narrow card wording may wrap; keep no-horizontal-scroll assertions. Preserve all preexisting workspace edits; revert only task-owned diffs if needed. No install/quit/launch of user App, no commits/pushes.
