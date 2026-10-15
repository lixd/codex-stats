# Normalize Token Display Units (R12)

## Goal
Make token amounts readable and consistent across charts and details, preserving precise accounting.

## Confirmed Evidence
- The first user screenshot is an older layout whose automatic vertical axis shows scientific notation: 4.0E8 means 400,000,000 tokens.
- The current chart in Sources/App/DashboardView.swift:271 uses locale-dependent compactName, giving Chinese 万/亿 units.
- Sources/App/Components.swift:64-73 provides abbreviated K/M/B and exact numbers, while TokenDetails at :236 still uses long integers.
- Shared TokenDetails is used by overview, session details and request/raw snapshot details; changing that component addresses all those surfaces.

## Requirements
- R12: use a shared, locale-independent international compact display: >=1,000,000 uses M, >=10,000 uses K, smaller integers remain exact. Values above one billion also use M.
- Examples: 400,000,000 -> 400M; 40,000,000 -> 40M; 109,946,996 -> 109.95M; 563,240 -> 563.2K; 0 -> 0.
- Compact output uses up to two decimals for M and one for K; never scientific notation or Chinese magnitude suffixes.
- Chart axis, menu/cards/rankings/tables and shared TokenDetails follow the same convention. Provide exact hover values for compact TokenDetails; preserve existing exact card subtitles and CLI integers.
- Missing cached/reasoning counters continue to say 未完整记录, never fake zero.

## Acceptance
- Today's hourly and 7-day daily chart screenshots use M/K in both light and dark modes.
- Shared TokenDetails displays M/K in overview, session, request and raw snapshot views; exact values remain accessible.
- Focused checks cover zero, small values, K/M thresholds, large values, unknown fields and locale independence.
- The 48-test Core baseline still passes; native App and installable DMG build successfully.
- Report actual rendering/build results without claiming real UI clicking or macOS 14 acceptance.

## Boundaries
No parser, total calculation, stored report schema, pricing, refresh interval, date range, or unrelated layout changes. Persistent project baseline is in docs/requirements.md and docs/design.md; documentation integration is owned by the parent.

## Review Status
PRD-only lightweight task. The user approved the presented final summary on 2026-10-14 (确认，开始吧); implementation and independent checks are complete. Results: check-result.md and VERIFICATION.md v0.2.5.
