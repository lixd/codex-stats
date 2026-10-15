# Independent refinement quality review

Reviewer: `refine_check`; date: 2026-10-15. Scope: the complete first-batch product diff, task PRD/design/implementation plan, design baseline and relevant backend/frontend specs. This review does not substitute for the root session's executed tests, native build, previews or benchmarks.

## Findings and resolutions

1. **P1, fixed and rechecked:** the first implementation allocated unknown session groups by full path, so identical active/archive legacy files became independent counted streams. Final grouping uses typed recorded/unidentified keys, retains conservative same-filename unknown-copy selection, and allocates opaque unknown IDs against all recorded/allocated IDs. The actual metadata ID alone admits native ownership. Added tests cover duplicate/prefix unknown archives, filename collisions, generated-prefix collisions, valid identity aliases and invalid copies affecting genuine responses/compaction.
2. **P2, documented limitation:** summary-key timezone invalidation does not rebucket scanner data; the scanner captures its timezone at startup. Current requirements/design/usage/statistics/spec explain restarting after a system timezone change. The native test verifies key inequality, not actual cross-timezone rebucketing. No runtime rebucketing claim is accepted by this review.
3. **Identity follow-up, fixed and rechecked:** a raw parent metadata reference could resolve an unknown generated internal group ID. Parent lookup now requires the selected parent's recordedSessionID to equal the raw parent reference; inheritedPrefix also verifies each child's declared parent against that recorded ID. The new generatedUnknownKeyCannotResolveDeclaredParentIdentity regression preserves child legacy usage and reports unresolved inheritance. Physical-rollout history lookup remains a distinct physical-boundary diagnostic mechanism, not proof of native ownership.

## Full-scope static checks

- Reviewed ownership checks through global conflict detection, compaction normalization, native accounting and companion-notification suppression. Rejected native provenance remains available for suppression; visible/copyable Session IDs use recorded metadata only.
- Reviewed the bounded one-entry UsageSummary, report/root invalidation, range/day/zone keys, retained successful summary after failed refresh, and precomputed session/model/list projections. No raw-log or unbounded query cache was added.
- Reviewed the B menu's 288pt layout, four metric cards, dynamic range label, unknown-field flags, first-load/error/retained-report states, exact-value help, refresh/quit hit areas and accessibility labels. Existing exact-menu close-before-analysis flow remains intact.
- Reviewed the Chinese TokenDetails labels, field-specific incomplete captions, and meaningful nonduplicated dashboard captions. Analysis-window geometry and timing estimation remain outside this batch.
- `git diff --check` executed by this reviewer and passed. No product code was edited by the reviewer.
- Heavy tests/build/render/benchmark jobs were deliberately left to the coordinating root session to avoid competing jobs. Their exact commands/results belong in VERIFICATION; they are not independently executed evidence from this reviewer.

## Gate

Final full-scope static recheck passed with no unresolved product-code blocker. Root must use the latest post-parent-guard test/build/benchmark results for release evidence; earlier 120-test results preceded that final correction. Live MenuBarExtra mouse interaction, macOS 14/Intel acceptance, long-running residency and runtime timezone rebucketing are not established by static review.
