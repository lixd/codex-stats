# Request layout implementation and native evidence

2026-10-15. Scope owned: `Sources/App/DashboardView.swift`, `Sources/App/RequestsContent.swift`, `Tests/UIPreview/main.swift`, and task-local measurement notes. Existing dirty changes preserved; parent owns design/version/build. Baseline copies and temporary harnesses live in `/tmp/codex-stats-compact-requests-20261015`.

## Product changes

- Requests-only header is one row, padding16/12; PeriodPicker shares `store.period` in count row. Page padding16/12, gaps8. Other page header geometry is unchanged.
- Native table uses ten columns when available table region >=900pt; seven paired columns below900. All ten fields remain present. The compact header order maps top/bottom values: model/type, new/cache input, duration/speed. Data12pt, existing type10pt, date/true-ID10pt. Numeric accessibility labels include exact value/unknown status. Full model/project/true-ID/value/timing/evidence help remains.
- Wide minima: time60/project80/model100/new72/output48/cache72/total58/duration58/speed80/type66. Flexible project/model absorb spare width. Narrow minima60/70/88/72/48/58/78. The900pt threshold reserves native spacing and17pt always-visible scrollbar; no scroller is hidden to mask overflow.
- A single native420×600 sheet reuses RequestDetailView, leaving the list full width. The same selection binding presents/dismisses it; production close and Escape clear selection. No independent presentation state, data-layer, scanner, palette, menu or lifecycle changes.

## Current-turn checks

- `xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path /tmp/codex-stats-compact-requests-20261015/module-cache -target arm64-apple-macosx14.0 -typecheck Sources/Core/*.swift Sources/App/*.swift`: PASS at first stable implementation. Parent optimized build subsequently compiled final width/accessibility changes; parent owns its evidence.
- `bash Scripts/render-ui-previews.sh /tmp/codex-stats-compact-requests-20261015/after-cyan cyan`: PASS exit0.
- `bash Scripts/render-ui-previews.sh /tmp/codex-stats-compact-requests-20261015/after-blue blue`: PASS exit0.
- Each full matrix contains147 PNGs and33 request geometry files. Every expected request table must exist exactly once. Tests assert native document <=clip+1pt, all columns including final rect visible, expected7/10 columns, actual native scroll ownership. Four80-record regular cases plus five forced-legacy cases per palette reach real last row and return first (9 each). Existing model80-row, palette state/pixel, menu fitting, diagnostic/state/error checks also pass.
- Both schemes and palettes capture real attached NSPanel sheets: `isSheet`, `sheetParent === ownWindow`,420×600. Same mounted request query/row selection/sheet survives cyan→blue→cyan; parent/menu/sheet pixels update without scan/report/summary invalidation. NSHostingController provides a real presenter; explicit content size preserves requested host dimensions. Synthetic sheet appearance matches the parent's synthetic appearance override; actual system preference was not changed.

## Geometry (pt)

| Host/state | Before top / height | After top / height | Before doc / clip | After doc / clip |
|---|---:|---:|---:|---:|
|1120×760 ordinary|254 /459|189 /538|962 /887|903 /903|
|950×630 ordinary|254 /329|189 /408|962 /717|733 /733|
|1116×760 ordinary|not measured|189 /538|not measured|899 /899 (7cols)|
|1117×760 ordinary|not measured|189 /538|not measured|900 /900 (10cols)|
|950×630 legacy80rows|not measured|189 /408|not measured|716 /716|
|1116×760 legacy80rows|not measured|189 /538|not measured|882 /882 (7cols)|
|1117×760 legacy80rows|not measured|189 /538|not measured|883 /883 (10cols)|
|1120×760 legacy80rows|not measured|189 /538|not measured|886 /886|

Table starts65pt earlier and gains79pt height. Native80-row visible ranges:1120 `{0,13}`,950 `{0,10}`. Also1050,1118,1280 ordinary sizes pass, both schemes. Legacy tests only set each temporary NSScrollView.scrollerStyle, never global user preferences.

## Visual review and limits

Inspected native1120 light,950 light/dark, blue1120 light and actual sheet captures: all fields/approximation signs/unknown text remain legible; long names truncate with full help; table final field is visible. Large synthetic Token values and unknown cache/speed remain explicit. Empty/error overview/model/menu and all-page warning/failure/recovery are covered by existing matrix. A final temporary-only harness separately rendered the real successful empty request report at950×630 in both palettes/light-dark (4PNG), asserted hasReport=true/no error/zero real records and exact host size, and visually confirmed header, range/search/model/sort controls, empty explanation and footer fit one page without scrolling. Evidence: `/tmp/codex-stats-compact-requests-20261015/empty-requests` and sibling `empty-requests.log`; temporary source/script retained there. Exit0; no product or repository test change was made for this extra capture.

This is offscreen native rendering and programmatic Table selection/scrolling, not mouse/trackpad feel or VoiceOver acceptance. Native accessibility press lookup for SwiftUI's close button failed (Code50) and was removed instead of asserting fake success. Final test teardown uses explicit AppKit endSheet, so production close/Escape, copy, manual sort/model Picker use remain manual. Actual macOS increased contrast was not changed. Intermediate Code43 from an NSHostingView-only presenter was resolved using NSHostingController and real postmount native row selection; intermediate dark sheet pixel Code32 was due to synthetic parent appearance not inherited by NSPanel, addressed only in harness. No product workaround was introduced.

No user App installation, launch, quit/replacement, real-log writes, commit or push occurred.
