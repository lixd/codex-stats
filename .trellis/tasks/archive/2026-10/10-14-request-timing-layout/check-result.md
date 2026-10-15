# Full-scope quality check — v0.2.7

Status: full-scope Phase 2.2 PASS. Final DMG/source artifact verification remains a root release step.

## Scope and method

No Git repository exists. Compared changed product sources and tests with `/tmp/codex-stats-v026-before-v027`; read PRD, design, implementation plan, research, backend/frontend indexes and concrete accounting, scan-performance, Turn-performance and Token-display contracts. Single repository; affected layers are Core decoding/report metadata, native App presentation, test/measurement harnesses, and documentation.

Reviewed all product changes: scoped autorelease pools at file reads and line callbacks; event-order request estimate capture and attachment; optional Codable estimate metadata; request duration/rate rendering and uncertainty text; compact native Models Table with one scroll owner. Existing aggregation/deduplication/accounting arithmetic is unchanged. Estimates are separate from full-Turn performance and only attach to accepted owned individual responses with matching explicit Turn evidence. Compaction, anonymous counters and initial snapshots remain unknown; conflicting copies/failed Turns deny estimates. Rates require at least 200 output Tokens and 1 second; duration bounds are rejected, never clamped.

## Independently executed checks

- `./Scripts/test.sh`: 114 tests PASS; Swift Package Core/App/CLI build succeeded. Existing missing CLT linker search-path warnings remain; no new compile/test failure.
- `./Scripts/test-token-display.sh`: PASS in en_US, zh_CN and fr_FR, 16 numeric boundary cases each plus shared axis/unknown/exact-value contracts.
- `bash -n Scripts/measure-app-memory.sh Scripts/render-ui-previews.sh Scripts/benchmark-performance.sh`: PASS.
- Standalone `xcrun swiftc -swift-version 5 -framework AppKit Tests/AppMemory/main.swift`: PASS.
- Memory-harness failure injection: a uniquely identified temporary App copy reached the 10-second sample, then intentionally failed writing to a missing output directory. Exit 1 reported the error and normal cleanup left no test-owned process. Evidence: `/tmp/codex-stats-memory-failure-check.txt`. The user's existing instance was not targeted.

## Visual inspection

Inspected rendered native `models-950-light.png`: model column begins visibly at the left edge; long model remains a single line with ellipsis and source help; excessive first-column gap removed. Narrow widths require native horizontal scrolling for right columns. Inspected `request-detail-known-light.png`: request estimate ≈45 s / ≈53.3 tok/s explicitly includes waiting/retry uncertainty, separated from complete Turn 120 s / 30 tok/s. Static rendering is not a scroll/click/hover or macOS 14 physical acceptance test.

## Findings and resolution

No blocking product-code violation found. Found a mechanical measurement-harness cleanup issue: post-launch `precondition` failures could bypass `defer`. With root authorization, changed only `Tests/AppMemory/main.swift` to throw through a function scope and perform bounded normal termination in `defer`; compilation and deliberate failure cleanup passed. Normal measurements still use the same 10/35-second sample schedule and vmmap physical footprint/peak fields.

The initially stale Turn-performance spec has been synchronized; reviewed the new Request Estimates contract, backend index and curated manifests, README, requirements/design and v0.2.7 verification section. They match the approved behavior and separate measured whole-Turn timing from request estimates. Root corrected one mechanical verification wording mismatch: the preview harness asserts request 45 s / 2400÷45 and unknown=nil; full Turn 120 s / 30 tok/s was visually inspected, not separately asserted by that harness.

Reviewed actual native App vmmap artifacts under `/tmp/codex-stats-app-memory-v026` and `/tmp/codex-stats-app-memory-v027`: built versions 8/9, test-owned process IDs, old current/peak 117.2/746.6 MiB at 10 s and 44.0/746.6 MiB at 35 s; new 26.4/30.7 MiB and 28.0/35.5 MiB respectively. Verification explicitly describes the controlled input and sampling limit. The harness does not independently assert completed refresh. Scanner-only footprint 61.45 MiB and RSS 83.53 MiB remain separate from App figures. Root reports exact benchmark accounting snapshots PASS, 7,020 records / 9,043,780 Tokens; consistent with the reviewed benchmark script and artifacts.

No unresolved product-code or document blocker remains. Root reports DMG build 9 completed. Final signatures/mounted contents/source packaging/checksums and archive-link validation remain root release checks. No real UI click/scroll/hover, macOS 14 physical, Intel, Developer ID or notarization acceptance is claimed.
