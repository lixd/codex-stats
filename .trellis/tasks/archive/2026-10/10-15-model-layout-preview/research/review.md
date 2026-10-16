# Independent native A review

2026-10-15. Review is against the selected A native contract, not the preceding HTML render or historical v0.2.14 evidence. Status: PASS; source/harness review, independent type-check, final cyan/blue native output review complete. No confirmed defect or mechanical fix remained.

## Source findings

- No confirmed source defect found in the model-only change. `ModelsContent` retains the same current-period `UsageStore.summary(in:)` source, case-insensitive name search and six sort cases, including name tie-breaks. No Store/Core/other-page changes, persistence, selection, timers or extra aggregation were introduced.
- Rendering uses a vertical `ScrollView` and `LazyVStack`, stable existing `ModelUsage.id`, 12pt group spacing, 18pt inset, 10pt outline, 14pt model name, 21pt total, and separate input/output groups. Long names and unknown labels are allowed to grow vertically. This matches the selected hierarchy; native images/geometry are reviewed separately below.
- Each token value uses the production `abbreviated` formatter and exact `detailedNumber` help/accessibilityValue. Cached and uncached use `cachedInputKnown`; reasoning uses `reasoningKnown`. Therefore unknown subsets remain unknown while known zero stays zero. Total remains Core's input + output and no cache/reasoning values are added twice.
- Source hashes initially compared to `implementation-before.json` differed only for the authorized `DashboardView.swift`, `Tests/UIPreview/main.swift`, and parent-owned `Assets/Info.plist`. The subsequent design-first approved test-only scope extension also changes `Scripts/render-ui-previews.sh` as described below. Existing unrelated dirty changes were preserved. The model replacement is scoped below `ModelsContent` in `DashboardView.swift`.
- Independently opened the previous source archive `/tmp/codex-stats-compact-requests-20261015/CodexStats-v0.2.14-source.zip`, required its DashboardView hash to equal `implementation-before.json`, and compared its prefix before `private struct ModelsContent` byte-for-byte with the current file: PASS. Exact model-only diff saved to `/tmp/codex-stats-model-groups-20261015/validation/model-only.diff`.

## Independent checks completed

- `git diff --check`: PASS, exit 0.
- Full App target type-check: PASS, exit 0, no diagnostics:

  `xcrun swiftc -swift-version 5 -target arm64-apple-macosx14.0 -module-cache-path /tmp/codex-stats-model-groups-20261015/check-module-cache -typecheck -parse-as-library -framework AppKit -framework SwiftUI -framework Charts Sources/Core/*.swift Sources/App/*.swift`

- Initial type-check without an explicit module cache failed because the sandbox disallowed writing the default user clang cache. Re-running with the isolated `/tmp` cache above succeeded; no code change or permission escalation was required.
- Independent full native preview-harness macOS14 target type-check: PASS. Same flags/cache as above, excluding `Sources/App/CodexStatsApp.swift` and including `Tests/UIPreview/main.swift` instead. This checks the new grouped-scroll, boundary, search/palette and legacy-only harness source.
- `bash -n Scripts/render-ui-previews.sh`: PASS. Compared with the hash-matching v0.2.14 archive, the script adds only two explanatory comment lines and one extra invocation of the same isolated preview binary with `--legacy-models -AppleShowScrollBars Always`. It reuses synthetic CODEX_HOME/palette and `set -e` failure propagation. The override is an argument of the child process; it does not write global/user scroll preferences.
- There is no configured project linter; whitespace validation and the compiler are the applicable source checks. Parent/implementer own this turn's Core/formatter and native preview runs; their actual results will be inspected rather than claimed from history.

## Not fixed / remaining verification

- No source fixes were needed and no confirmed issue remains open in the reviewed scope. Parent owns final baseline/version/doc status, source archive and delivery verification.
- Static rendering, source AX semantics and programmatic NSScrollView evidence do not establish real mouse/trackpad interaction, non-default native Picker keyboard selection, VoiceOver speech or macOS14 runtime behavior. These remain explicit manual acceptance boundaries.
- No user App was installed, launched, quit or replaced; no real logs were read and no commit/push was made by this reviewer.

## Native output review so far

- Independently inspected current-run `cyan/models-1120-light.png`, `models-950-light.png`, and `models-950-dark.png`: model names/totals are separated, input/output hierarchy is clear, and unknown cache/uncached/reasoning text is fully shown in the 1120pt render. At 950pt a third group continues below the viewport, as expected for a vertical scroll.
- Inspected `cyan/end-models-many-950-light.png` and `end-models-many-1120-dark.png`: the final sorted `synthetic-model-0` group is visibly present in full, including its input/output/subset values. This supplies identity evidence beyond a bottom-coordinate assertion.
- Corresponding native geometry files show document/clip widths 717/717 at950 and887/887 at1120; document height12960pt for80 genuine models. The harness checks Store count80, reaches actual document bottom, and saves end images; lazy child count is not substituted for data count.
- Current `cyan/palette-switch.txt` records same-host native field edits and cyan→blue→cyan state preservation in light and dark. Reviewed the model-specific assertions: filtering reduces document height; a no-match native-field edit removes the model ScrollView; restoring the query restores filtered height; switching palette keeps query, filtered height, summary identity, range/root and success timestamp. `switch-cpu-*.png` provides the corresponding mounted-host renders. These are programmatic controls/binding checks, not physical input or VoiceOver proof.
- Offscreen SwiftUI virtual accessibility nodes were opaque in early harness attempts. Those attempts failed, and no runtime field-level AX/count PASS is claimed. Exact AX semantics are supported by source review only; speech and interactive assistive technology remain manual.
- Final cyan boundary screenshots at950/1120light show the full long name (multiple lines), large total/input/uncached values, all three unknown subset labels without truncation, and genuine zero cached/output/reasoning fields. Boundary geometry at950 is717/717. At950 the last zero group continues below the viewport as expected; at1120 all three groups are visible.
- Inspected final cyan legacy950 top and legacy1120 bottom images; the final sorted model0 is fully visible. Final legacy geometry is700/700 at950 and870/870 at1120. The test verifies both `NSScroller.preferredScrollerStyle` and the actual scroll's style are `.legacy`, plus its vertical scroller. The final child covers light mode at both widths; legacy dark was not run. Post-mount forced-style attempts failed and were replaced by the process-start override, not by changing product widths or weakening the assertion.
- Read `/tmp/codex-stats-model-groups-cyan.log`: ordinary matrix and independent legacy child both finished with PASS. Framework/XPC warnings remain in native host stderr; they are not substituted for success or counted as interaction verification. Parent's current-run formatter log passes en_US/zh_CN/fr_FR, and its Core host log reports133 tests passed. These runs were inspected, not redundantly re-executed by this reviewer.
- Final blue ordinary matrix and legacy child also finished with PASS (`/tmp/codex-stats-model-groups-blue.log`). Independently inspected blue1120light,950dark, boundary950dark/1120light, and every blue end image (950/1120 light/dark ordinary plus950/1120light legacy): no clipped long name/large value/unknown state, known zero retained, and final `synthetic-model-0` present in full in all six blue bottom renders. Cyan bottom renders were likewise inspected across950/1120light/dark ordinary and950/1120light legacy.
- Independently parsed all28 current-run model geometry records (14 per palette): document width<=clip width in every ordinary, many-model, boundary and legacy case. 80-model records all confirm document-bottom reach. Evidence saved to `research/review-geometry.json`. Each palette has159 current-run PNGs. This count describes generated files, not159 independently inspected images; representative visuals and all model bottom identity images were inspected as listed above.

## Final verification summary

- Lint equivalent: PASS (`git diff --check`, shell `bash -n`; no project linter configured).
- TypeCheck: PASS (independent full App and preview-harness macOS14 target).
- Tests: PASS (inspected current Core133/formatter3locales; final native matrices and isolated legacy children both palettes PASS; independently parsed28 model geometry records and inspected layout/edge/end images).
- Fixed findings: none; no product/test source modification by reviewer. Review report and parsed geometry evidence are the reviewer's only writes.
- Remaining manual boundaries are explicitly retained above; they are not reported as passed.
