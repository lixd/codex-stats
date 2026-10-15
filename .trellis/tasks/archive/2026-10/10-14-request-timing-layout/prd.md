# Scan memory, request estimates and model layout

Status: approved for implementation. After the final planning summary, the user requested fixing the speed fields and delivering a new version (2026-10-14). Includes the proposed memory/layout fixes and explicitly marked request estimates.

## Goal

Keep Codex Stats lightweight during cold scans, make the model table readable at normal window widths, and show useful request performance with explicit provenance and uncertainty.

## In scope, in order

1. Fix scanner temporary-object lifetime at file reads and JSON line decoding, without altering accounting, caching, owned response selection or user logs.
2. Tighten model column spacing; prevent clipped/wrapped model names; keep numeric headers/rows aligned and one horizontal-scroll owner at narrow widths.
3. Introduce CC Switch-style **estimated** request duration / output rate. Show ≈ and an explanation; do not call it measured generation speed. Keep the independently sourced whole-Turn timer distinct.
4. Add meaningful regression coverage, memory benchmark evidence, narrow/light/dark model previews, and synchronize requirements/design/verification docs. Build a new App/DMG and source archive after checks.

## Out of scope

Network calls, proxying, credentials, API costs, account/quota features, changing refresh defaults, rewriting token accounting, persistent caches, closing/replacing the user's running app, or modifying CC Switch.

## Acceptance criteria

- [x] Same generated 350 MB input: scanner peak footprint falls by at least 75% relative to freshly compiled baseline, with separate RSS measurement and exact equal accounting snapshots; cold/warm/append timing documented.
- [x] Native App cold-load peak and settled footprint actually measured after the fix; report method/input and limits. Do not present scanner-only results as App measurements.
- [x] All Core tests pass, including partial/corrupt line and cache invalidation behavior.
- [x] Model names start visibly at the table's left edge, stay on one line, and don't consume oversized blank space at 950/1120-point previews; horizontal scrolling stays possible when needed.
- [x] Estimated request timing is paired to an accepted individual response, sourced from event ordering. Ambiguous/cumulative/initial snapshots remain unknown. Compaction, duplicate snapshots, interrupted turns, delayed notifications and physical copies have regression cases.
- [x] Duration outside plausible bounds remains unknown; output-rate eligibility uses the researched thresholds, and incomplete evidence never fabricates values.
- [x] Right inspector describes estimate scope separately from known whole-Turn performance; exact Token totals and copied real IDs remain unchanged.

## Key decisions and risks

- RAM is priority: 1.1 GiB is the running App's lifetime peak, not current resident usage (~131 MiB at last sample). Scratch scanner peaks fell from ~788–795 MiB to ~59 MiB with equal reports; The release build has now been measured separately on the same controlled input.
- CC Switch 4.0.6 estimates from local events, not a hidden request duration field. Adopting that estimator changes the previously approved strict request-performance presentation; the user has now requested implementing and delivering this behavior.
- Estimates may include waiting/retries and may miss a true boundary. Their purpose is approximate activity analysis, not a speed benchmark. No guessed model or Token quantity is introduced.
- Existing whole-Turn performance coverage rules stay intact.
- Model layout defect requires confirming scroll origin plus sizing rather than only reducing font size.

## Evidence / artifact status

Research and scratch measurements: research.md. Proposed technical approach: design.md. Execution and checks: implement.md. Implementation and checks completed; v0.2.7 build 9 App / DMG packaging and signature checks passed. Trellis bootstrap task remains separate.
