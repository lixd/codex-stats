# Overview Model Query (R21/T15)

## 1. Scope / Trigger

Read when changing the filtered overview, scalar query index, Store overview cache or model-to-request navigation. It consumes accepted ScanReport only; Scanner ownership, replay, counters and date attribution are outside this module. Product target: docs/dashboard-model-filter-design.md. Current validation status belongs in VERIFICATION.md.

## 2. Signatures

- `OverviewIndex(report:timeZone:)` builds immutable scalar day/session/model usage, day/model record counts and absolute-hour/model usage.
- `summary(in:model:now:timeZone:) -> OverviewSummary` exposes usage, models, dailyTotals, hourlyTotals, recordCount, modelRecordCounts.
- `ValuationIndex.summary(in:model:now:timeZone:)` applies the same optional exact model and day bounds to existing Decimal buckets.
- Store overview query is a single bounded summary cache, separate from the original menu/nonfiltered summary. The same captured now/zone/period/model must reach usage and valuation.

## 3. Contracts

Nil means all models. Model strings are exact accepted log identity, never inferred price aliases. Model counts in the dropdown are for the selected period before model filtering, with candidates from all observed history. Zero records in another range retains selection and shows a real empty state. recordCount is UsageRecord count, never claimed to be confirmed request count.

All displayed overview sections use the same query: reference USD/coverage, Token, weighted cache ratio, count, trend, model breakdown and Token details. The overview's model state does not alter menu/nonoverview summary semantics. The existing shared period still does. Existing request page accepts an initial model when opened from overview; no duplicate table or global persisted model setting.

Build scalar indices on the background worker with the accepted report. Query no records/JSON/Decimal construction; do not retain a second whole record array or a cache for every model/range. Repeated identical queries reuse one summary object. Snapshot/report/price replacement, model, period, local day/zone changes invalidate correctly. Price edits must not leave a stale filtered dollar value. Filter/palette changes do not scan, restart timers or forge refresh times.

## 4. Validation / Error Matrix

| Case | Expected |
|---|---|
| nil model | Usage/day/hour sums equal original report aggregates |
| exact model | All cards, trend and details agree; other models excluded |
| absent model or no records in period | Real zero/empty; no silent reset to all |
| missing cache or price | Existing typed incomplete/partial/unavailable states preserved |
| input0 | Cache ratio noInput; output-only still estimable when priced |
| DST day | 23/25 absolute hour buckets, repeated local clock hours remain distinct |
| retained scan failure | Same accepted report/price pair plus visible failure |
| palette only | Preserve query, selection, report and successful time |
| price change | Same Token/count; new effective revision and valuation |

## 5. Good / Base / Bad Cases

Good: gpt-6-sol I1000/C800/O100 gives1100Token and0.00156USD at2/.2/10; adding a cache-unknown record retains this known subtotal and exposes the rest. Base: all selection equals Core's accepted report. Bad: use the model picker to filter the table while overview cards remain unfiltered; average per-model cache percentages; collapse an absent selected model into all.

## 6. Required Tests

Independent multi-model/multi-day hand oracle; per-model and nil usage/day/hour/count/price consistency; all four periods; DST 23/25 buckets; real zero and unknown states; unchanged scanner counters. Store object reuse/invalidation, no scan on model queries, retained errors, palette/price transitions and initial model navigation. Native950/1120 both schemes/palettes with startup legacy scrolling must show document<=clip and readable partial states. Screenshot/form binding checks are not proof of a pointer-selected native dropdown or VoiceOver.

## 7. Wrong vs Correct

Wrong: `report.records(...).filter(...).map { Decimal(...) }` inside overview body, or changing a global model setting that silently narrows menu totals.

Correct: local overview selection queries the worker-built scalar index and paired valuation; explicit navigation carries the model to the existing request page.


## Trend projections (R23/T16)

OverviewSummary exposes dailyRecordCounts/hourlyRecordCounts; ValuationSummary exposes daily/hourly CostEstimate maps. Hour identity is absolute Date, built with an injected Gregorian timezone and supports DST23/25 hours. Background valuation calculates each accepted record once then merges that same estimate into day/session/model and hour/model buckets. Do not retain records or reprice in query/view. Same overview model/period/now/timezone applies to usage/count/price, existing bounded Store cache and atomic reprice invalidation remain. Missing-cost buckets have typed coverage, never zero money; known zero prices remain complete. Check daily/hourly totals, model/ranges, DST and unavailable/partial/zero/micro states with independent literal expectations.
