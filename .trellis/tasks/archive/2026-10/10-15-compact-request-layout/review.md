# Independent Trellis review

2026-10-15. Compared this task's before snapshots/before-hashes, not cumulative dirty Git diff. Reviewer made no product/test edits while implementer owned those files.

## Findings (fixed)

- `Sources/App/RequestsContent.swift:117–118`: compact paired token Text accessibilityLabel contained only field names. Implementer added exact `detailedNumber(...known:)` accessibilityValue after review, preserving numeric/unknown semantics without changing visual formatting.
- `Tests/UIPreview/main.swift`: optional request Table lookup could silently skip geometry and row assertions. Implementer now requires exactly one real native request Table for request/inspector captures and expectedRequestRows, then asserts document/clip/final-column geometry. This checks rendered native geometry rather than expected SwiftUI padding alone.
- Legacy vertical-scroller coverage was initially absent. After review requested measurement, implementer reserved width for it and added tests; final native legacy950/1116/1117/1118/1120 checks all pass.

## Findings (not fixed)

- Production close-button/Escape, reopen-after-close, nondefault model/sort Picker interaction and physical trackpad/mouse/VoiceOver remain manual acceptance. Actual native request sheet presentation, sheet palette redraw and programmatic AppKit dismissal are tested; endSheet does not execute the production close binding. Attempted native AX close lookup was unavailable and removed without claiming it passed. Source close button still clears selection with cancel keyboard shortcut; no confirmed product defect found.
- Actual system increased-contrast setting remains unverified, as before. Resolved role contrast math and ordinary light/dark images are different evidence.

No unresolved confirmed product defect in the reviewed scope. These limitations are evidence boundaries rather than speculative defect claims.

## Verification

- Lint/whitespace: `git diff --check` passed. No dedicated Swift linter configured for this scope.
- TypeCheck: independent `xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -module-cache-path /tmp/codex-stats-compact-requests-review-cache -typecheck Sources/Core/*.swift Sources/App/*.swift` passed. Final UI harness compiles production App sources and both full matrices passed.
- Tests: parent-run133 Core tests and shared formatter en_US/zh_CN/fr_FR logs passed this round; reviewer inspected logs rather than rerunning identical tests.
- Worker-run cyan/blue native matrices: both `/tmp/codex-stats-compact-requests-20261015/after-{cyan,blue}.log` end in PASS. Request Table existence/count, zero horizontal overflow, actual attached420×600 sheets,80 real rows and final-row programmatic reach are asserted. Same-host palette/search/selection and sheet pixels remain tested.
- Native dimensions (both ordinary palettes):1120×760 doc=clip903;950×630 doc=clip733. Table top189 versus old254, height538 versus459 at1120 (79pt more). Actual legacy scroller metrics:950=716;1116=882 (7columns);1117=883,1118=884,1120=886 (10columns); every document equals clip.
- Independently inspected1120light,950light,950dark,1117thresholdlight,1117legacy80-rowlight and420×600 actual sheet screenshots for cyan, plus blue950light. All fields/headers/controls fit; unknown values/≈/units and true-ID secondary lines retain meaning. Long project/model names have complete help; no body font reduction.
- Scope before-hashes: only DashboardView, RequestsContent, UIPreview and Assets/Info.plist changed among recorded Sources/Tests/Scripts/Assets. Core, Store, menu, lifecycle, formatter and delivery scripts unchanged.

No user App/log modifications, install/quit/replacement, commit or push performed by reviewer. Parent owns final docs/version/package closeout; review does not treat documentation pending during the gate as final drift.
