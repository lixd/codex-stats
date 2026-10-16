# R22 final verification — v0.2.19/build21

2026-10-16. Baseline v0.2.18/build20; implementation follows the approved formal deletion design. Existing dirty workspace preserved; HEAD remains11f2a937971c40d29a2b4d69ff6bb79c5eaec91f. No commit/push or user App operations, real logs/configuration writes.

## Current evidence

- Task-start versus final product/test/script/assets hash comparison changes exactly4files: DashboardView.swift, Tests/UIPreview/main.swift, Scripts/render-ui-previews.sh, Assets/Info.plist. ProductionCore/Store/CLI/other-page components/palette/lifecycle and their tests are byte-identical. Private page code, enum route/icon and page-only test helpers are removed; shared model aggregates remain. No alias or hidden page replaces it.
- `Scripts/render-ui-previews.sh …/ui-cyan cyan` and `…/ui-blue blue`: implementer executed both, each exit0,149PNG/35TXT. Four-page warning/retained-failure/recovery, native request width boundaries/80realrows/last-row reach/sheet, actual search/draft bindings and palette retention, valuation assertions, menu and unknown states pass. Old model-page fixtures/legacy flag removed; request legacy coverage retained.
- Root `Scripts/render-overview.sh …/overview`: exit0, four palette/startup-scroller processes pass. Production overview selected/all/unknown-price/cache-incomplete/empty/long-name/largeUSD/retainederror at950/1120 in light/dark; actual document<=clip. Handoff initial model renders8real request rows. Representative cyan1120priced image independently checked by root; four-item sidebar, filter, four cards, chart/distribution/fulldetails intact.
- Independent trellis-check read-only diff/source review and representative four-page/nativegeometry verification: no blocking confirmed defect. Separate final macOS14arm64 `-O` frontend typecheck exit0/no diagnostics,55Sources/Tests/Scripts hashes unchanged during check. See research/review.md. Typecheck is not a runtime test or executable optimization measurement.
- `Scripts/build-macos.sh /tmp/codex-stats-remove-model-statistics-20261016/native`: root final optimizedarm64 build exit0; Info0.2.19/build21, target14+. `codesign --verify --deep --strict` exit0.57Sources/Tests/Scripts/Assets frozen inputs are byte-identical before/after build. ExecutableSHA256=63cbfa00b873cefbdf73a6a1ac235fb1faaa9fe783f3ef38361bb3d9d498b0c3.
- `git diff --check`, script shell syntax and Trellis context validation pass. Current docs/specs reflect four sections; older model-layout-proposals.md marked historical, prior evidence retained.

## Evidence limits

No new Core/Store/formatter suite is claimed: those implementations/tests did not change, full native harnesses compile their real code and exercise existing assertions. Prior145Core results remain historical. This UI deletion does not warrant another full accounting/performance benchmark. No measured memory/latency improvement is claimed. Offscreen seeded state/programmatic text edits do not prove actual pointer/keyboard/VoiceOver navigation. macOS14/Intel runtime, system increased contrast, DeveloperID/notarization and long-running lifecycle remain unverified. No user App was installed, launched, quit or replaced.

## Delivery and manual check

Dedicated root `/tmp/codex-stats-remove-model-statistics-20261016` contains native/Codex Stats.app, App/sourceZIPs,ui-cyan/ui-blue/overview and logs. App is locally ad-hoc signed. SourceZIP is a current workspace export including preserved earlier changes, not a clean Git commit. ZIP CRC/bytes/frozen inputs are checked in external validation/delivery.json after packaging.

User acceptance: in the new App verify only总览/请求日志/历史会话/设置, select a model and period on总览, inspect its fullToken/amount/cache and viewrecords; confirm settings price management and session model details remain available. Actual clicks/VoiceOver are pending user acceptance, not proved by static previews.
