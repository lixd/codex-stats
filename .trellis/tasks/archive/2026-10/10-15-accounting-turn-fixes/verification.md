# Accounting and Turn attachment implementation handoff

Date: 2026-10-15. Approved target: [audit-fixes-design](../../../../../docs/audit-fixes-design.md). R13/R16 and T01/T03/T04/T06–T11. This is the implementer handoff; parent integration checks are separate.

## Boundary and changes

- `Sources/Core/CodexLogScanner.swift`: covered cumulative/last-only notifications seed the same anonymous replay signature used by later last-only notifications. Independent response IDs, genuinely growing counters, and different Turns remain eligible. Counter subtraction reports known-to-unknown subset inconsistency. Turn attachment builds temporary per-session/per-Turn evidence and uses sorted interval existence queries instead of rescanning every frame and row for every Turn.
- `Sources/Core/Models.swift`: only `TokenUsage.difference` was changed by this implementer. Parent input/output resets still return nil. Monotonic parents survive invalid child deltas; each invalid child becomes unknown with internal zero, while a valid other child remains known. Session projection edits elsewhere in this shared file belong to the A04/A05 implementer and were preserved.
- `Tests/CodexStatsCoreTests/CodexLogScannerTests.swift`: independent truth assertions for paired replay (including archive/prior/cumulative variants), distinct response/Turn controls, each invalid/reset subset, missing fields, native subtraction, zero-parent correction and later recovery.
- `Tests/CodexStatsCoreTests/TurnPerformanceTests.swift`: each counter relevance path (Turn/time/start/end/frame range/missing time, with irrelevant control) and a genuinely inherited paired cumulative companion.

No product docs, version, specs, installation, user App, real logs, staging, commit, push or task archive were changed by this implementer. The parent owns those integration boundaries.

## Current execution evidence

1. `Scripts/test.sh --filter 'pairedNotificationsSeedLastOnlyReplayEvidence|pairedReplayEvidencePreservesIndependentResponsesAndTurns|invalidCumulativeSubsetsKeepParentsAndExposeUnknown|nativeDeductionDoesNotClampInconsistentSubsetRemainders|missingSubsetDifferenceDoesNotInventValuesOrAnomaly'`
   - Before product changes: 5 tests, 64 failed assertions. Controls for independent responses/Turns and missing fields passed. Replays produced 220 rather than 110; invalid child deltas were clamped or whole deltas discarded. [Before log](evidence/accounting-before.txt).
2. Same filter plus `duplicateRequestRecordDoesNotConsumeANewEqualSizedRequest` after A01/A03 changes: 6 tests passed, including all parameterized cases, zero failures. [After log](evidence/accounting-after.txt).
3. Broad Turn/request/accounting filter after indexing: 55 tests executed; 54 passed. One new test had three failed assertions because its last-only companion cannot establish the existing legacy inherited-prefix proof (which requires cumulative evidence). [Initial index test log](evidence/core-targeted-after.txt). Corrected that fixture to contain matching cumulative and last usage; no product change was made in response to this fixture error.
4. Using the current successfully built `.build/debug/codex-stats-report --records`, generated three independent temporary JSONL cases and asserted zero-parent correction, recovery after a nonzero unknown delta, and the corrected inherited companion. All 3 passed. [Exact CLI outputs](evidence/cli-boundaries.json). Test roots were under the system temporary directory, never real Codex logs.
5. `git diff --check` over the four product/test files passed. Final full suite, fixed-input differential snapshots and performance benchmarks are intentionally serialized by the parent; this handoff does not claim they passed.

The last fixture correction and two additional zero-parent/recovery unit tests have not yet been rerun through Swift Testing in this branch; the same observable behaviors passed the real CLI check in item 4. Parent must run the final suite. Existing CLT linker search-path warnings were observed; no dependency was installed.

## Preserved coverage and design clarification

Turn indexes include all physical frames, not only accepted rows. They retain `pairedNotifications(inherited: 0)`, all copy-level invalid/partial/history vetoes, failed/conflicting lifecycle rejection, explicit ownership and membership, and frame range OR Turn ID OR inclusive time OR missing-time counter relevance. Unassigned native evidence still denies output coverage. Known duration/TTFT can survive unknown output/count, exactly as before. Request estimates were not refactored.

Parent clarified the zero-parent case in the authoritative design before the added boundary tests: a contradictory subset correction with zero new input/output emits `counterAmbiguity`, adds no fake zero-usage row, and does not rewrite previously accepted evidence. Known flags on those prior rows describe that accepted evidence. A later valid increment may have known children again; any earlier nonzero unknown row keeps the aggregate child unknown. The diagnostic remains visible in either case.

## Integration inputs and limitations

The corrected accounting / pre-index source checkpoint is retained outside the repository for exact A02 comparisons. [Location and SHA-256](evidence/before-index-source.json) identify the copied Core files and report entrypoint. Parent prepared independent full-output differential cases and will compile/run that checkpoint and final source serially. Do not compare against the original inaccurate A01/A03 behavior for affected cases.

No benchmark result or performance guarantee is claimed here. Expected cost is one evidence pass plus per-Turn indexed membership and interval queries; arbitrary heavily overlapping lifecycle candidates still carry their inherent response-set work. No persistent cache or generic query framework was added. Actual App interaction and platform acceptance remain integration limitations.


## Final integration handoff

Parent completed the final 133-test suite, 126-case differential, fixed-input accounting/scale verification, optimized native build, isolated lifecycle and App footprint checks. See [integration evidence](../10-15-small-beautiful-fixes/verification.md). Child-local statements that parent integration was pending describe the earlier handoff. Native clicks/Esc remain explicitly unverified because the Mac is locked. No production App operation or commit occurred.
