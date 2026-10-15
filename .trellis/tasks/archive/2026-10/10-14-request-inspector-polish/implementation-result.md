# Request Inspector Polish — Implementation Result

Status: implementation gate complete; independent check in progress. Root task owns release, documentation integration and final acceptance. The check has identified additional cross-copy invalid-completion and unattributed interval-response coverage cases for reproduction/fix. The 96-test result below predates that check and is not a final approval or proof that those cases pass.

## Implemented

- Remaining main Token captions use the shared K/M formatter: menu footer, metric subtitles, session headline and request-list total. Exact values remain available through help, copy and offline reports; unknown values remain unknown.
- Diagnostics are grouped using existing typed severity and kind. Information uses a cyan information icon; warnings and errors retain an orange risk marker. Every original message and file reference remains available in expandable details. Compact menu details have bounded scrolling.
- The request list uses the native Table's own scrolling rather than an oversized nested horizontal ScrollView. Timestamp is the first column and visible at dashboard widths 1120 and 950. Each row has an explicit detail action.
- Request details appear in a 360-point right inspector. Selection is recomputed from current rows; closing clears selection without recreating the search/model/sort controls. The production view includes close and Escape handlers.
- Request duration and speed show — with a clear explanation because the available protocol does not record request timers.
- Separately labeled complete Turn performance reads explicit duration and optional TTFT. Average output tok/s requires proof of complete, owned, deduplicated response coverage across all copies. Its numerator is the whole Turn, including responses outside the current date/model/search filter. The scope explicitly includes tools and waiting.
- Contradictory completion timers, errors, aborts (including identityless aborts), invalid TTFT, foreign ownership, inherited/partial/corrupt histories and unpaired cumulative events cannot produce a false mean. Explicit zero TTFT remains distinct from missing TTFT.

## Changed Implementation Files

- `Sources/Core/Models.swift`
- `Sources/Core/CodexLogScanner.swift`
- `Sources/App/Components.swift`
- `Sources/App/MenuPanelView.swift`
- `Sources/App/SessionsContent.swift`
- `Sources/App/DashboardView.swift`
- `Sources/App/RequestsContent.swift`
- `Tests/CodexStatsCoreTests/TurnPerformanceTests.swift`
- `Tests/UIPreview/main.swift`
- `Scripts/render-ui-previews.sh`

The root-authored `.trellis/spec/backend/turn-performance.md` was checked against implementation and corrected to describe recorded session metadata plus explicit owned native responses as the lifecycle ownership proof. Lifecycle events themselves have no owner field.

## Executed Verification

| Command | Result |
|---|---|
| `./Scripts/test.sh` | PASS: 96 tests; final log `/tmp/codex-stats-inspector-tests.log` |
| `./Scripts/test-token-display.sh` | PASS: 16 formatter boundaries in each of en_US, zh_CN and fr_FR |
| `./Scripts/test-usage-store.sh` | PASS: real scanner pending, refresh, root failure, zero and stale state checks |
| `./Scripts/build-macos.sh /tmp/codex-stats-inspector-build` | PASS: native arm64, macOS 14 target, ad-hoc signed `/tmp/codex-stats-inspector-build/Codex Stats.app` |
| `./Scripts/render-ui-previews.sh /tmp/codex-stats-inspector-previews` | PASS: 26 native production-component PNG previews |
| `bash -n Scripts/render-ui-previews.sh` | PASS |

Timing regressions cover complete multi-response Turn, duplicate responses and archived copies, cross-day/model filtering, invalid or missing lifecycle fields, zero TTFT, conflicting repeated completion, abort/error after completion, invalid duplicate TTFT, identityless abort, foreign owner, missing owner, inferred Turn membership, unpaired cumulative frames, damage, partial/inherited history, physical response conflicts and repeated compaction.

## Native Preview Evidence

All 26 images are under `/tmp/codex-stats-inspector-previews`. Both appearances cover overview/day and seven-day trend, menu, requests and inspectors at 1120/950, known/unknown timing details, grouped diagnostics, first loading, successful empty scan and missing-root error.

Inspected images include `requests-1120-light.png`, `requests-950-dark.png`, `inspector-950-light.png`, `inspector-1120-dark.png`, both menus, known light and unknown dark details, `diagnostics-light.png`, `first-load-dark.png`, `empty-light.png` and `error-dark.png`. Final diagnostics and first-loading captures have the production background; the initial transparent captures were replaced.

The first-loading image directly renders the production pending component with its loading state. Empty and error previews use actual synthetic empty and inaccessible-root scans. Synthetic timing fixtures are labeled preview evidence; they do not claim measurements from the user's live corpus.

## Verification Boundary / Remaining Acceptance

The build and native static rendering ran on this host. They do not establish installation or interaction on macOS 14.

An attempted offscreen NSHostingView action experiment could not reliably expose real SwiftUI row actions or propagate programmatic NSTableView selection. The unsuccessful experimental harness was removed; no fake action check or success claim remains in source. Actual row clicks, Escape, close, filter/search/sort and scroll-position preservation, clipboard actions and end-user installation remain manual acceptance items. The implementation is ready for independent source/test review without further automation retries.

Token accounting and scan optimizations remain independent of timing metadata. No costs, providers, network calls, model guessing or request-latency estimator were introduced.
