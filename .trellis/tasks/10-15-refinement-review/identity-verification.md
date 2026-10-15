# Core identity implementation evidence

Implemented after the task and `docs/data-design.md` approved-pending identity refinement were recorded:

- Native ownership requires a nonempty recorded session metadata ID. Global response conflict/compaction normalization uses the same gate.
- Missing-metadata grouping uses typed unknown filename stems; same-stem active/archive copies retain one conservative legacy stream. Internal IDs allocate from an opaque unidentified:stem namespace with collision checks against every recorded and allocated ID. An unverified filename collision cannot select or poison a verified session stream.
- Rejected native frames retain companion-notification pairing provenance, including notifications immediately before the native row.
- `SessionUsage.recordedSessionID` defaults to nil for hand-built data; scanner fills only explicit metadata. Missing-ID title uses `未记录 ID`.
- CLI session `id` remains an internal key; optional `recordedSessionID` carries the real identity and is omitted when unknown.
- Public bounds API widening was considered then removed before final verification. Existing Core visibility and filtering algorithms are unchanged.

Validation:

1. `./Scripts/test.sh`: final run **121 tests passed, 0 failures**, 0.101 seconds test execution; native App target built as part of the package. Existing CommandLineTools linker search-path warnings remain. Log: `/tmp/codexstats-refine-core-tests.log` (local temporary evidence).
2. Seven new regression tests cover missing metadata filename ownership with prior/following companion cumulative/last-only notifications; contradictory unverified response/model/compaction cannot poison a genuine copy; unidentified legacy filename collision remains a separate group while preserving both actual usages; `session_meta.session_id` alias still verifies ownership; identical and prefix unknown archive copies count once; arbitrary recorded IDs cannot collide with allocated internal keys; generated unknown keys cannot resolve declared metadata parent references. Existing missing-metadata legacy test now asserts unknown session identity/title and namespaced internal key.
3. `.build/out/Products/Debug/codex-stats-report Tests/CodexStatsCoreTests/Fixtures --records`: synthetic canonical fixture gives input250/cache180/output30/reasoning15, 2 records, real identity `fixture-session`.
4. Temporary synthetic missing-metadata legacy CLI input: recordedSessionID absent, internal key namespaced, input100/output10 retained.
5. `git diff --check Sources/Core Sources/Report Tests/CodexStatsCoreTests docs/data-design.md`: pass.

Two earlier package attempts ran while the projection worker's consumer code was still being adjusted and failed App type-checking; these were resolved before the successful final command. No claim of live UI or macOS14 runtime acceptance is made by these checks.

Independent review caught a regression in the first path-per-file namespace: same-name unknown active/archive counters could double-count. The target was revised before further code edits to typed known/unknown-stem grouping and collision-checked internal keys. Final 120-test run includes this correction; the earlier 118-test result is superseded.

Final parent-identity audit: selected[parentID] and inheritedPrefix both require the parent candidate's real recordedSessionID to equal the declaring child metadata parentId. Generated unknown keys cannot prove inheritance. Remaining internal-ID lookups only select groups or compare self identity; native global conflicts, compaction and row admission use recorded ownership; performance candidates filter recordedSessionID. physical[rolloutID] is a separate immutable physical-history diagnostic lookup and does not admit usage or prove ownership. Final package run after this guard: 121 tests passed, 0 failures in 0.101 seconds; prior120 count superseded.
