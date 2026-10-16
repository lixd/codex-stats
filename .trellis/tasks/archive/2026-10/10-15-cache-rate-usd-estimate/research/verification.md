# Final verification: v0.2.16 / build18

2026-10-15. R18/R19, T12/T13. Root reviewed the plan, approved off-main scalar indexing, completed cache-rate gate before money, then an independent checker reviewed final code/evidence. No source commit/push, real-log scan or installed/running user-App operation.

## Current-turn results

| Gate | Actual result |
|---|---|
| Final host Scripts/test.sh | exit0;138 Swift Testing tests passed, final encoding included (0.414s test phase, not benchmark) |
| Real App formatters | en_US/zh_CN/fr_FR pass; weighted ratio, zero/no-input/unknown, half-cent, tiny USD, exact help and unavailable-no-zero |
| Real Store harness | pass; synthetic scanner, matching report/index, pre-assignment callback invalidation, ranges/palette, failure retention/root reset and obsolete-root rejection |
| Independent scanner/CLI manual oracle | final optimized Core+Report rebuilt;6 accepted records, input2800/output340/total3140, exactUSD0.00693, covered1830/uncovered1310; hierarchy sums match; unavailable amount null; unknown ratio/counter null; output-only USD0.00005 |
| Native wide matrix | cache-only and cost full matrices, both palettes exit0; existing model80/search/state/legacy checks retained |
| Final frozen-source native gate |64 targeted PNG across cyan/blue, light/dark,950/1120, overlay/legacy;16 model geometries document==clip717/887 or700/870; request420×600 bottom-region derived fields fit |
| Independent App typecheck | macOS14 target exit0, empty diagnostics |
| Final native build | Scripts/build-macos.sh independent /tmp output exit0; v0.2.16/build18 arm64 macOS14 target |
| Signature/dependencies | codesign --verify --deep --strict exit0; otool libraries only OS frameworks/runtime; ad-hoc, no notarization claim |
| Scope/whitespace | git diff --check pass; Scanner/Models/App lifecycle/request Table unchanged from task-start; code-source hashes match final build |

Artifacts: `/tmp/codex-stats-cache-usd-20261015/`. Logs: validation/core-host-final.log, display-final.log, store-final.log, targeted-*.log, validation/check-typecheck.log, validation/build-host-final.log, validation/independent-oracle-final-result.txt. `implementation.md` gives exact synthetic benchmark and matrix commands. `review.md` records independent visual/source review. Retained manual oracle fixture and expected/result are beside this file; `build-source-hashes.json` and `delivery.json` identify final product sources and executable.

The initial native build was interrupted by a final MenuPanelView AX-label edit during compilation; it exited1 and is not a successful result. The final build after source freeze exited0. An earlier restricted full runner stalled and was terminated only for its own processes; it is not counted as a passing test. Final host138-test run passed.

## Controlled resource measurement

Optimized synthetic100000 accepted records,100 sessions,10 days,4 models:4000 scalar buckets; one build0.318323583s, one all-range merge0.003881917s, exactUSD281.2. This measures this new index only, not cold scan, redraw/scroll smoothness, RSS, current footprint, peak footprint or virtual memory. No new record copies or per-sort Decimal work found in source.

## Limits and manual acceptance

Offscreen native captures and programmatic controls prove rendering/state paths, not real mouse hover, VoiceOver speech, native Picker keyboard interaction or system high-contrast switching. These remain manual, as do macOS14 runtime/Intel and long-term residency. Existing real-log historical audits remain historical, not this round's data. Catalog excludes nonstandard charge dimensions and unpriced internal/unknown models; this is reference usage value, not actual subscription/API billing. The new App is not installed/launched and the user's old App remains untouched.

## Reproduction

Run Scripts/test.sh, Scripts/test-token-display.sh, Scripts/test-usage-store.sh; render both palettes with Scripts/render-ui-previews.sh OUT cyan|blue. For focused captures compile Sources/Core/*.swift + App sources except CodexStatsApp.swift + Tests/UIPreview/main.swift as the existing render script does, then run --valuation-only and --legacy-models -AppleShowScrollBars Always against the retained synthetic oracle directory. For CLI use the same Core + Sources/Report/main.swift and --records; compare against independent-oracle-expected.json, not production-generated expected values. verify-oracle.py contains portable assertions against the retained independent-cli-final.json; regenerate that JSON with the CLI against the adjacent oracle-input before rechecking a later build.
