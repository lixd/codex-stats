# Derived Usage: Cache Rate and Reference USD

## Scope

v0.2.17 R18/R19/R20, T12/T13/T14. Read before changing UsageValuation.swift, Store valuation, CLI derived fields or the compiled reference catalog. Metering remains Scanner/Models.swift; this module consumes accepted records and must not reinterpret deduplication, model identity or dates. See [design](../../../docs/cache-rate-cost-design.md).

## Signatures and Data Flow

- `CacheRate(usage: TokenUsage)` exposes state/input/cachedInput/fraction.
- `CostEstimate.calculate(usage:model:catalog:)` exact-matches the effective PriceCatalog; nil catalog marks configuration unavailable. The price overload is a pure checked Decimal calculator.
- `ValuationIndex(report:catalog:)` traverses sessions[].records once on ScanWorker and stores scalar session/day/model buckets, not records.
- `summary(in:now:) -> ValuationSummary` merges buckets using existing DayBounds; total/models/sessions/sessionModels must agree with record totals.
- App publishes one ScanSnapshot containing report and index. Snapshot didSet invalidates a summary built by synchronous @Published pre-assignment callbacks. Refresh failure retains the pair; root reset clears both; old-root scans cannot publish.

## Contracts and Serialization

Rate is sum(cache)/sum(input), not mean percentages. States: known, noInput, incomplete. JSON includes counters and fraction; incomplete cachedInput and non-known fraction are null.

USD = ((input-cache)*inputPrice + cache*cachePrice + output*outputPrice)/1000000. Construct exact Decimal prices from strings, check NSDecimal operations and round only in presentation. Reasoning is already output. ReferencePricing supplies the default snapshot only when no local file exists. PriceCatalog persists the complete effective table with revision and per-row builtIn/custom provenance. All historical dates use that same current table; editing makes a row custom. No runtime requests, keys or historical bill claims.

CLI adds derived to total/model/session/session-model; --records adds recordDerived keyed by internal record ID. Cost JSON: state, exact amountUSD string or null, USD currency, priceVersion, priceSources, estimatedTokens, unestimatedTokens, reasons. Original integer counters remain unchanged. Never expose an internal record key as a real response ID.

## Error and Unknown Matrix

| Input | Result |
|---|---|
| input0 | Rate noInput; output-only can be priced without cache split |
| nonzero input, unknown cache | Rate incomplete; this record excluded from money |
| missing exact price | Nonzero usage excluded, missingPrice reason |
| zero usage | Complete actual0 even if model unpriced |
| all positive usage covered | Complete reference estimate |
| covered + excluded records | Partial subtotal, both coverage counters and reasons retained |
| all positive usage excluded | Unavailable; JSON amount null, UI no numeric zero |
| arithmetic failure | Explicit calculationFailure; never fake success/zero |

## Good / Base / Bad Cases

Good: sol I1000/C800/O100 ->0.00148USD; reasoning changes alone do not affect money. Base: known cache0 gives0.0%, input0 gives noInput. Bad: average rates100% and0% across I100/I900 gives50%; correct weighted result10%. Bad: merged model cache-unknown drops all known money; correct per-record index retains its known subset. Bad: run Decimal arithmetic inside sorting/body or store a duplicate records array; use scalar cached summaries.

## Required Verification

Scripts/test.sh (current test count in VERIFICATION.md), test-token-display.sh (actual App formatting in three locales), test-usage-store.sh (atomic pair/willSet invalidation, failure/reset/range/palette), render-ui-previews.sh (two palettes/light-dark, menu288, models950/1120 overlay+legacy, partial/unavailable/micro and request bottom). Independent scanner/CLI hand oracle must match all hierarchy sums; update catalog only with source/date, independent calculations and tests. Tests/ValuationScale is timing-only synthetic evidence, not memory/UI responsiveness proof.

## Wrong and Correct

Wrong: infer unknown model prices from prefixes, treat missing cache as0, double-charge reasoning, encode unavailable amount0, call an API or read account configs. Correct: exact catalog matches, typed unknown state and visible coverage, offline Decimal reference value. Full mouse/hover/VoiceOver/system contrast and macOS14/Intel runtime remain manual until actually executed.


## Local Price Catalog (T14)

`ModelPrice` validates all three nonnegative decimal strings without Double conversion or silent precision loss; zero is valid, blank/negative/exponent/overflow are not. `PriceCatalog` rejects duplicate exact models and unknown schema versions. Source metadata describes each stored snapshot; do not require old builtIn values to equal a newer compiled default table.

`PriceCatalogFile(url:)` is the shared App/CLI reader. Default is `~/Library/Application Support/Codex Stats/prices.json`; tests must inject a temporary URL. Missing file alone selects defaults without writing. Atomic save writes the whole effective table; empty is valid. Never merge defaults into a saved table, resurrect deleted built-ins, overwrite corrupt files by fallback, or write user logs. Invalid/unreadable configuration throws: App preserves a previous good pair with visible error (or unknown money on initial failure); CLI returns nonzero stderr. CLI `--prices PATH` is read-only test/repro injection.

Store's ScanSnapshot contains report, catalog, scalar valuation and all-history observed exact models. Candidates subtract configured entries from accepted records across all dates, excluding Unknown model. No extra JSONL scan for page/candidates/price changes. Both row sources share deletion protection: any accepted historical record prevents deletion; no successful/full trustworthy scan, active scan or scan failure also prevents uncertain deletion. Recheck in delete action; editing used models remains allowed.

Persist before committing state; serialized ScanWorker performs file IO and valuation. Captured catalog revision and report generation reject stale results across scan/edit/root races. Repricing retains the old complete report/index pair until a new pair publishes and invalidates summary; no new timer. Cost help uses actual result revision/source and points to per-row metadata instead of labeling custom or historical snapshots with compiled defaults. Zero-usage CLI groups must still carry the effective catalog revision.

Verification: independent fixed hand oracle for baseline/add/edit/empty and every hierarchy; corrupt config/invalid CLI args; Store persistence, guarded deletion, no-rescan price edit, overlap, root reset and failed writes; formatter locales; actual native management/add/edit states in two palettes/light-dark at950/1120 with overlay and legacy geometry. Static form images alone do not prove native sheet presentation or real keyboard/VoiceOver behavior.

## Model-filtered overview and catalog additions

For R21/T15, read [overview-query](overview-query.md). `ValuationIndex.summary(in:model:now:timeZone:)` takes an optional exact model; nil retains the original all-model query. Compiled pricing r2 adds gpt-5.6-sol (4/0.40/20) and gpt-6-sol (2/0.20/10), USD per million, with per-row official source. Never infer a codex-auto-review price. Existing complete catalogs do not merge by startup: `missingNewBuiltIns` and `addingNewBuiltIns()` support the explicit Settings action, preserving existing exact model rows and all other deleted built-ins. Test default, custom, empty, persistence and failure before changing this rule.
