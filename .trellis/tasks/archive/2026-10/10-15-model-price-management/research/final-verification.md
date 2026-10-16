# Final frozen verification

2026-10-15, v0.2.17/build19. Sources/Assets frozen manifest and artifact root: `/tmp/codex-stats-price-management-20261015/`.

- `validation/core-frozen.log`: Scripts/test.sh exit0, 142 tests.
- `validation/store-frozen.log`: final rebuilt actual Store regression exit0.
- `validation/display-frozen.log`: final rebuilt production formatter en_US/zh_CN/fr_FR exit0.
- `validation/cli-oracle.json`: final optimized Core/CLI baseline/add/edit/empty, all hierarchy sums and explicit error scenarios pass. Metadata-only session current revision additionally checked in every scenario. Fixture and fixed expectations copied into research/oracle.
- `review/typecheck-macos14-final.log`: independent optimized macOS14 arm64 typecheck exit0, stable Sources hashes.
- `ui-verified.log`, `regression-cyan.log`, `regression-blue.log`: native production views/static form/real text-binding and document<=clip geometry pass; matrix compiled before last internal immutable Decimal cache change only. Final Core/Store/formatter/CLI/build revalidated after that change.
- `validation/build-final.log` and `build-verified.json`: final independent App build exit0, version17/build19, strict/deep signature valid, system linkage only,16 input files stable. Intermediate source-modified build failure remains recorded, never counted as pass.
- price row Decimal caching single-sample100k build1.0550→0.2859s, sameUSD281.2; no memory/frame/cold-scan claims.

No installed/running user App operations, real logs/config, commits or pushes. Actual pointer/dropdown/save-cancel/Escape/VoiceOver/system HC and macOS14/Intel runtime remain unverified; offscreen AX attempts explicitly UNVERIFIED. Full factual detail and manual checks: VERIFICATION.md v0.2.17 section. Complete source archive includes preexisting dirty source work intentionally preserved. Trellis archive/journal use --no-commit as user requested.
