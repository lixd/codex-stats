# Independent R23/T16 review

Status: prepared, waiting final implementation freeze. This is a separate reviewer; product edits belong to implementer until freeze.

## Predeclared hand oracle

`review-oracle.swift` constructs accepted synthetic reports directly, without Scanner, production preferences or user files. Fixture uses Asia/Shanghai midnight crossing, model A rates 2/.2/10 USD/million, zero-price model Z, and unpriced U.

| Range | Records | Token | Exact USD subtotal | Unestimated Token |
| --- | ---: | ---: | ---: | ---: |
| Today | 6 | 1872 | .00307 | 210 |
| 7 days | 7 | 1982 | .00319 | 210 |
| 30 days | 7 | 1982 | .00319 | 210 |
| All | 8 | 1987 | .00319 | 215 |

Today local hours 00/01/02/03: counts 3/1/1/1; USD .00306/unknown/0/.00001; coverage partial/unavailable/complete/complete. A filtered today is 4 records/1761Token, U1/100 unavailable, Z1/11 known zero; absent model has no records. Doubling A's three prices gives .00614 and preserves210 uncovered. New York DST spring/fall have23/25 axes, two distinct populated absolute-hour keys, each exactly .00001USD.

Expected values above were written before compiling the oracle. Running status and exact outputs will be appended below.

## Preliminary review

- Scalar count and valuation indices use the accepted report, exact model identity and the same bounds; one record valuation is merged into day and absolute-hour buckets, without record copies or per-render scanning.
- UI date set comes from selected-model daily record keys, shared across the three modes; no-record state uses recordCount, not zero Token.
- Partial/unpriced markers have visible triangle plus words. Full-unpriced range uses explicit unavailable state. Known zero does not become unavailable.
- Found a usability issue in the first implementation: chart money ticks used the shared two-decimal card formatter, so all ticks below $.01 were identical '< $.01'. Sent to implementer for local correction before freeze; final status pending.
- Native preview modes are seeded production states. They are not proof of real mouse/keyboard/VoiceOver segmented-control interaction.

## Independent execution (2026-10-16)

- Independent hand oracle: **PASS**, 40 literal assertion lines. Output `/tmp/codex-stats-trend-20261016/review/oracle.log`. Command: copy production Core sources into private `review/frozen-core`, copy task `review-oracle.swift` to `review/main.swift`, compile with `xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 frozen-core/*.swift main.swift -o oracle`, then run. Before/after private snapshot/current Core hashes agree; source evidence `review/oracle-core-hashes.json`.
- Initial harness invocation incorrectly used parse-as-library for top-level code; corrected only harness invocation/name (main.swift), then full compile/run passed. No product change.
- Task-start source/asset hash comparison currently shows only OverviewIndex, UsageValuation, DashboardView, Core overview tests, Store tests, native overview host and root-owned plist changed. Preexisting Git dirty history was excluded from this assessment.
- No configured separate SwiftLint/SwiftFormat file found. Final lint equivalent will use whitespace diff check, shell syntax for applicable scripts and compiler diagnostics; do not label an absent configured linter as executed.
- Native current first-pass blue950 partial and all-unpriced images examined: controls and help fit, no visible unpriced/footnote overlap. Implementer is removing the shared min190/frame168 ambiguity and improving micro-dollar axes before final freeze. Dense30date state requested separately.

## Final frozen review, first pass

- Independent optimized whole Core+App macOS14 arm64 `swiftc -typecheck`: **PASS**, zero diagnostics,51 Sources/Tests/Scripts inputs unchanged throughout. Logs `review/typecheck.log`, hashes `review/final-input-hashes.json`.
- `git diff --check` and `bash -n` existing overview/Core/Store/formatter scripts: PASS.
- Micro-axis and unavailable sizing fixes reviewed in source: three significant dollar axis digits preserve .00001/.00002 distinction; unavailable content has its own168pt frame and no shared190pt minimum.
- **Confirmed readability defect, returned to root/implementer before further source edits**: final cyan950 `dense-30dates-cost.png` draws30 categorical date labels and29 adjacent marker captions; date strings visibly overlap, and annotations concatenate “未计价小计未计价小计” into a continuous line. Geometric document<=clip assertions alone do not catch this. Recommended bounded6 categorical ticks plus dense-point symbol-only policy with a visible textual legend, preserving detailed AX/help. Design decision left to root before implementation. At this point build acceptance is withheld pending correction/review.

## Density revision

Root updated the formal design before the readability fix: about6 evenly spaced date ticks including endpoints, dense markers use triangle/diamond plus persistent visible legend. Initial revision had `showWords` accidentally passed to `trendValue` instead of `trendMarks`; independent typecheck caught the missing/extra argument and implementer was asked to fix before build. Log `review/typecheck-density.log` is a **failed intermediate** check, not final verification.

Reviewer also noted that hiding the annotated Text removes its `.help` hover target; per-point AX remains. Root must describe supported hover/AX evidence accurately instead of claiming untested per-point hover was preserved.

Corrected call sites compile cleanly: `review/typecheck-final.log` has zero diagnostics and51inputs stable (`review/accepted-final-hashes.json`). OriginalCore oracle hashes remain unchanged. However the next native screenshot (`overview-density-final/cyan/dense-30dates-cost.png`,12:11) still renders all30 date labels despite `AxisMarks(values:ticks)`; point caption overlap is fixed but x labels still overlap. Returned this concrete remaining defect to implementer/root, recommending explicit conditional label emission. Compiler/geometry pass does not satisfy this visual acceptance.

## Accepted final review

**Review PASS after correction.** Source explicitly guards `AxisValueLabel` with the selected tick set. Visually inspected `overview-axis-final/cyan/dense-30dates-cost.png` (12:16) and `cyan-legacy/dense-30dates-records.png` (12:17): six readable endpoint-preserving dates, all30data buckets retained, diamond vs triangle and visible legend distinguish unknown from subtotal without overlapping words. Also inspected final cyan950dark record mode: native controls, integer counts and explanation fit. Earlier micro/known-zero cases remain current because formatter/valuation logic did not change.

Final independent optimized Core+App macOS14 arm64 typecheck: **PASS**, no diagnostics, `review/typecheck-axis-final.log`; all51 source/test/script inputs unchanged during check (`review/axis-final-hashes.json`). Original hand oracle's Core hashes still match final source, so all40literal checks remain valid. Final whitespace/shell checks pass. No configured standalone Swift linter exists.

No remaining confirmed in-scope defect. Real mouse/keyboard segment changes, VoiceOver output, dense per-point hover, actual macOS14/Intel runtime and memory/resource measurements are **not verified** by these synthetic offscreen native checks. Dense per-point AX is present in code; root clarified formal contract to preserve AX and range help rather than claiming per-point hover in dense charts. No product code edited by reviewer: discoveries were coordinated with the owning implementer/root, preserving compiler freeze.

Root owns optimized distributable/signature/input-hash delivery validation and task closeout. This review does not itself claim installation, productionApp launch, commit, push or source packaging.
