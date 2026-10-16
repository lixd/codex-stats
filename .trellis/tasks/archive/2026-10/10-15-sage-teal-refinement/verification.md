# Current task verification (2026-10-15)

## Scope and provenance
Source started at HEAD11f2a937971c40b29a2b4d69ff6bb79c5eaec91f with existing audit fixes uncommitted. start-hashes.json separates this task delta. All runtime inputs below are synthetic. No user App install/quit/replacement, real-log mutation, commit or push.

## Executed before final visual review
- `Scripts/test-token-display.sh`: PASS16 boundaries × en_US/zh_CN/fr_FR, real formatter/unknown/exact values. Log `/tmp/codex-stats-sage-teal-20261015-token.log`.
- `Scripts/test-usage-store.sh`: PASS real scanner, bounded summary, range/day/timezone/report/root invalidation, values, unknown fields, diagnostics and failure/retry/recovery. Log `/tmp/codex-stats-sage-teal-20261015/validation/store.log`.
- `Scripts/test-menu-lifecycle.sh`: initial restricted LaunchServices launch failed10827; rerun with approved full-host execution passed exact-window handoff/dashboard ownership/reused-replaced menu/residency/normal termination. Only its UUID test app operated. Logs validation/menu.log and menu-retry.log.
- `Scripts/test.sh`: initial nested SwiftPM sandbox_apply not permitted. `--disable-sandbox` plus cache/config/security dirs under task output compiled successfully, but restricted runner did not complete; interrupted own session130. Identical command with approved full-host execution passed133 tests,0 failures in0.192seconds, App target compiled. Existing CLT linker-path warnings remain. Log validation/core-final.log. SwiftPM's flag disables its nested sandbox, not the host workspace boundary.

## Final native evidence

- Host:macOS27.0.1/build26A434,arm64,AppleSwift6.4/SDK27. Product targets macOS14.0; macOS14/Intel were not exercised.
- Final `Scripts/render-ui-previews.sh /tmp/codex-stats-sage-teal-20261015/previews` with approved full-host execution:PASS88 PNGs. Real light/dark five pages, menu B fitting288pt,950/1120,unknown/empty/load/errors/recovery/status details, few3/many80 models. Baseline sparse4 + many4 native NSTableViews assert exact row counts/noalternation/own NSScrollView;80-row tables reach final row programmatically. This is not mouse/keyboard interaction proof.
- Main visually inspected overview light/dark, sparse model light, requests light and selected-session dark; implement/check agents additionally inspected menu,950-dark many-model and inspector, settings/recovery and session light. Layering, selected border, risk text and real unknown data remain visible. A07 narrow inspector geometry remains deferred.
- Actual reused dynamic sRGB roles match design in light/dark. Min custom text4.511:1;white/action4.563:1;risk-opacity fills>=4.858:1. Full evidence:`previews/theme-contrast.txt`, copied to this task.
- HC synthetic attempt failed honestly:SDK NSAppearance.h says HC names are matching-only. Full-host minimal probe confirmed appearanceNamed/currentDrawing normalized to Aqua/DarkAqua. Removed misleading fakeHC PNGs. IntendedHC stroke swatch min3.660:1 is mathematical only; real system HC switching/redraw,VoiceOver and actual mouse/copy/Escape remain unverified. No OS preference changed.
- Preview initial compile errors (CGFloat arithmetic/read-only colorSchemeContrast injection) were fixed in test harness; final native build/check passed. Restricted iconutil failed after successful product compilation; same unique-output build with approved full-host execution succeeded. No fake success fallback.
- Final `Scripts/build-macos.sh /tmp/codex-stats-sage-teal-20261015/native`:PASS0.2.12/build14. Strict deep codesign,plist,arm64,minOS14.0,only system frameworks/Swift runtimes passed. Product SHA256:`13f8d57d85fc634d6fb86c057b0b3499f9c4902b527749719fabcdc298ae8977`. Logs:`build-final.log`,`validation/product.json`.
- Independent Trellis check:PASS,0 confirmed new product defects; see review.md. Product code not edited by reviewer. Core/UsageStore/AppLifecycle/delivery scripts match starting hashes. Presentation correction after initial tests was informational-diagnostic fill only; final previews/build compiled the final Components.

No earlier audit benchmark is claimed as this task's performance result. No performance/memory claim added. No real-log independent accounting comparison repeated because Core/data flow are unchanged. Final source scope/link/format checks are recorded at closeout.


## Closeout

Archived using --no-commit; Bootstrap Guidelines left unchanged. git diff --check passed; 79 current changed-document/spec/task local links valid; manifests6+6 valid after archive. Task-start comparison confines source changes to5App presentation files,Info.plist andUIPreview. Core/CLI/UsageStore/AppLifecycle/delivery scripts and prior test fixtures unchanged. HEAD unchanged11f2a937971c40b29a2b4d69ff6bb79c5eaec91f and Git index empty. Details:closeout.json/start-hashes.json/end-hashes.json.
