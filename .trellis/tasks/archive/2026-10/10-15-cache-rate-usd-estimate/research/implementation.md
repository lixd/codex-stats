# Implementation evidence — cache ratio and USD reference estimate

2026-10-15, implement agent. Product files are frozen; root owns current documentation, version/build and delivery. All input below is synthetic. No real logs, installed user App operations, commit or push.

## Boundary and flow

- New `Sources/Core/UsageValuation.swift`: CacheRate's known/noInput/incomplete states; versioned exact four-ID catalog; Decimal per-accepted-record calculation; explicit complete/partial/unavailable amount coverage/reasons; scalar session/day/model ValuationIndex and current-range ValuationSummary.
- `ScanWorker` builds the index by visiting `report.sessions[].records` once after scan, without a flat records array or retained record copies. One `@Published ScanSnapshot` pairs report/index. `report` remains a computed read property; no product `$report` consumers existed. Snapshot didSet invalidates the bounded summary after publication, including a synchronous pre-publication summary query.
- `UsageSummary` merges scalar buckets only. No record arithmetic in list sorting or ordinary body redraw. Request detail calculates only its one accepted record. Existing date bounds and captured session-detail now retained.
- `Components.swift`: real shared cache formatter/help/AX and cost formatter/help/AX. Currency rounds via NSDecimalRound before decimal-string grouping; direct NumberFormatter on NSDecimalNumber failed a half-cent assertion, so it is not used for money arithmetic/formatting. Micro-positive values display `< $0.01`. Unavailable help never supplies numeric zero.
- Menu, overview, model A groups, session/details and accepted-request details integrate compact metrics. Model complete amounts are under the right total; partial/unavailable may use a full-width line so qualifiers/reasons do not truncate. No new request-table columns, sort, preference, task or timer. Settings exposes fixed reference metadata and omitted dimensions.
- CLI preserves existing usage/record fields and adds `derived.cacheRate`/`derived.cost` at total/model/session and optional `recordDerived[id]`. Cache ratio includes typed state, exact input/cache counters and fraction; unknown cache/fraction are null. Cost amountUSD is exact decimal string for complete/partial, null for unavailable; complete actual zero is string `0`. Coverage and reasons remain explicit.
- Catalog: `openai-standard-short-2026-10-15`; USD Standard short input/cache/output only, uniformly for all historical usage. Exact matches only; reasoning is already output; no price inference, network or credential/config read.

## Cache-only gate before money

- `Scripts/test.sh --disable-sandbox --filter cacheRateStatesAndWeighting`: PASS1 focused Core test.
- `Scripts/test-token-display.sh`: PASS en_US/zh_CN/fr_FR, weighted10.0%, known0.0%, no-input and incomplete, exact help.
- `Scripts/render-ui-previews.sh /tmp/codex-stats-cache-usd-20261015/cache-{cyan,blue} {cyan,blue}`: both final exit0. At first gate both 950-light models document=717pt, clip=717pt; 288pt menus rendered. Implementer inspected cyan950 and reported gate before money. Both full matrices subsequently passed, including real80-record/model bottom geometry and existing state/palette tests.

## Money tests and measured cost

- New Core tests independently hand-check all four catalog values: 1000 input/800 cache/100 output => sol0.00148, astra0.0078, luna0.000078, codex0.00189 USD. Tests include reasoning exclusion, exact-only IDs, output-only, zero, unknown cache/price, partial retained within one model bucket, null unavailable JSON, micro/large sums, arithmetic NaN/overflow, all/model/session/direct equality and day/range bounds.
- `Scripts/test-token-display.sh`: PASS3 locales with half-cent grouping, real zero, micro USD, cent boundary, minimum8-digit exact help and unavailable no-fake-zero checks. Log `/tmp/codex-stats-cache-usd-20261015/display-final.log`.
- `Scripts/test-usage-store.sh`: PASS with real synthetic scanner; fixed Decimal value0.000129, total/model/session consistency, range invalidation, failed-refresh retention, root reset, atomic snapshot published payload vs currently stored pair, synchronous willSet query invalidation and obsolete-root rejection. Log `store-final.log`. Current palette/state tests retained.
- Root executed full host `Scripts/test.sh`: PASS138; final encoding amendment requires its final host gate. Root also maintains an independently calculated scanner/CLI oracle. Do not count the restricted full runner as a pass: it stalled after test starts and only confirmed own swift-test93523/helper93649 were terminated (session63814 exit143), releasing the lock for root host run.
- Optimized synthetic scale command: `xcrun swiftc -O -swift-version 5 -parse-as-library Sources/Core/*.swift Tests/ValuationScale/main.swift -o /tmp/codex-stats-cache-usd-20261015/valuation-scale`, then execute once. 100000 accepted records,100 sessions,10 dates,4 models ->4000 scalar buckets. Index build0.318323583s, one all-range merge0.003881917s, exactUSD281.2, estimated110000000 Tokens, no uncovered. Log `scale-final.log`. One observation, not a cold scanner/UI speed or RSS/footprint/peak-memory claim.

## Native matrices

- `Scripts/render-ui-previews.sh /tmp/codex-stats-cache-usd-20261015/final-{cyan,blue} {cyan,blue}`: both exit0. Includes prior complete model/session/request/status/palette/80-record tests plus dedicated four-model full/partial/unavailable/micro captures. Hand oracle0.0092801 USD,2201 covered/210 uncovered asserted in actual Store. New valuation legacy fixtures cover both950/1120 and light/dark per palette, document=clip700/870pt.
- These complete runs preceded a layout-only adjustment moving complete model amount under the right total (partial/unknown full-width text unchanged). Final-source valuation-only matrix and request-bottom images are recorded below after completion. Original complete matrix remains evidence for unchanged interactions/geometry; no claim it rendered the later complete-amount position.
- Actual mouse/hover, VoiceOver speech, nondefault native Picker keyboard operation, system increased contrast switching, macOS14/Intel runtime remain manual. Native static screenshots/programmatic scrolling do not establish those.

## Scope audit

Against task `implementation-before.json`, changed existing owned source/tests are exactly Components,DashboardView,MenuPanelView,RequestsContent,SessionsContent,UsageStore,Report/main,TokenDisplay,UsageStore tests,UIPreview. New files UsageValuation,UsageValuationTests,ValuationScale. Root's Info.plist version is separately owned. Original Scanner,Models,Appearance,lifecycle,request Table and scripts match task-start hashes. Preexisting unrelated dirty work is preserved. `git diff --check` PASS.

## Final frozen-source focused native gate

Final `Tests/UIPreview` executable compiled successfully from current product sources, with `--valuation-only` test mode. Using only root's synthetic oracle directory as bootstrap input (not modified), four isolated processes ran cyan/blue × ordinary/process-launch legacy. Commands use `CODEX_HOME=/tmp/codex-stats-cache-usd-20261015/oracle-input CODEX_STATS_PREVIEW_PALETTE=<palette> /tmp/codex-stats-cache-usd-20261015/final-valuation-preview <output> --valuation-only`; legacy appends `--legacy-models -AppleShowScrollBars Always`. Each passed and exited0.

- Outputs `targeted-cyan`, `targeted-blue`:28 PNG each,4 model geometry records each. Model full/partial/unavailable/micro at950/1120 light/dark; menu288; overview/session/settings950; accepted request details with explicit top and `end-valuation-request-{known,missing,micro,unknown}-{light,dark}.png` bottom images. Request bottom capture asserts actual native document<=clip and reaches actual document end.
- `targeted-cyan-legacy`, `targeted-blue-legacy`:4 PNG /4 geometry each, both widths and light/dark; actual preferred/scroller legacy asserted before measurement. Final16 model geometry records have document==clip717/887 overlay,700/870 legacy.
- Implementer inspected current cyan model950-light, menu, overview950; blue dark session; known/missing/micro/unknown request-bottom images. Complete amount is visible under right total; partial shows subtotal plus110 unestimated/cache-reason; request80.0%, true0.0%, incomplete, missingprice, microUSD and coverage text are visible, never fakezero. Reviewer has independently been sent final paths.
- Full preceding money matrices have183 PNG each, cache-only matrices159 each. These counts distinguish earlier full geometry/state runs from final64 targeted PNG. No actual screen/VoiceOver/user-App operation inferred.
