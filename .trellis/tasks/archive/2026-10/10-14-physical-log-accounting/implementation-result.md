# Implementation result

## Scope and decisions

Implemented Core accounting, structured diagnostics and CLI export only. No App layout, timestamp parser/filter performance, Turn timing, root tasks/status, Git, credentials or installed/running app was changed.

Files changed:
- `Sources/Core/CodexLogScanner.swift`: physical-source grouping, native dedup/conflict validation, conservative legacy selection, local reference validation, explicit diagnostic emission.
- `Sources/Core/Models.swift`: `DiagnosticSeverity`, `DiagnosticKind`, `ScanDiagnostic`, `ScanReport.diagnostics`; `warnings` is a computed warning/error message projection for current App callers.
- `Sources/Report/main.swift`: JSON includes typed diagnostics and retains existing exact Token integer values plus warnings projection.
- `Tests/CodexStatsCoreTests/CodexLogScannerTests.swift`: 19 additional synthetic tests; previous longest-archive test now expects verified-prefix information rather than a false conflict warning.

Stable SessionMeta.id groups sessions, while native expenditure is collected from all physical generations. A genuine owned response is charged once globally. Positive compaction evidence is normalized across owned copies before conflict checks: a shorter copy ending before a later marker is not contrary evidence. An unambiguous explicit payload model is authoritative; absent explicit models remain Unknown model for compaction. Conflicting identity attribution (owner, model, Turn, event timestamp) or usage excludes that ambiguous response with a structured warning for every affected physical source/Session; cumulative thread snapshots are deliberately not compared as response identity because they can differ after compaction. Internal row identities include the physical source path and position to avoid stable-session position collisions. Latest activity selects deterministic display metadata; first/last activity spans all physical files.

Malformed native rows retain ownership provenance even when response_id or usage is absent; rejected foreign/unknown records cannot become legacy child consumption. A verified same-owner malformed-ID row permits an independently valid legacy token_count under the existing counter rules, with its rejection diagnostic retained.

Native thread_id must be explicitly nonblank: it is never inferred from file SessionMeta.id. Missing-owner and foreign native records remain excluded, matched token_count notifications are suppressed, and unpaired counter boundaries following unverifiable native records cannot silently resurrect their consumption. Native notifications still never cross-difference thread_token_usage and total_token_usage.

Old unidentified counters are not unioned across divergent copies. The selected longer stream remains conservative. If it accepts legacy rows, extra native records in other copies are not merged because their consumption may already be present in that stream; explicit divergentAccountingCopies warns of possible undercount. Fully native generations retain distinct owned response IDs. Equivalent or strict nonempty complete frame prefixes are informational. Empty/damaged files never prove an ancestor.

Physical history references use Codex's immutable UUID filename suffix, including reverted stable_UUID / rollout_UUID filename forms. The index checks the actual complete JSONL byte boundary against the stored exclusive ordinal (ordinal is not line number), validates nonempty ancestry, missing targets, malformed/truncated boundaries and cycles. Corrupt lines after the exclusive referenced prefix do not invalidate it; those corruption diagnostics remain independently visible. A 0-byte/0-ordinal prefix imports no history and stops traversal. References never read outside already enumerated session/archived files. No conversation bodies are retained.

Source contract checked at local primary Codex commit `2f05c0a71f59fb2f05800846351f3e9926c3e52b`: protocol.rs HistoryPosition and SessionMeta; rollout ordinal.rs assigns next from history_base end ordinal; recorder.rs writes session_meta with current ordinal and advances it. Prefix gaps are not treated as line-number mismatches.

## Validation

- Added regressions before implementation. Initial compile failed because the old report lacked typed diagnostics; the old longest-copy behavior is separately established by the parent metadata-only research and the new 330-token dual-generation oracle fixture.
- `./Scripts/test.sh`: **67 tests passed** (48 existing + 19 new), after fixing the old false-warning expectation and a test call missing `try`. Test logs: `/tmp/accounting-tests.log` (temporary, not bundled).
- `./Scripts/build-macos.sh /tmp/codex-stats-accounting-build`: native arm64 macOS-14-target app compiled and ad-hoc signed successfully; did not launch or install. `codesign --verify --deep --strict` also passed. Build logs: `/tmp/accounting-build.log`.
- Release-optimized Core harness against `/tmp/codexpulse-frozen`: **29 files / 29 sessions / 6,714 records / 890,273,713 Tokens**, preserving the earlier single-physical-generation frozen baseline. Per-session record/model/hourly sum invariants and global row ID uniqueness passed; unchanged rescan cached **29/29** files. The sanitized corpus intentionally omits three referenced physical histories, so three unresolvedHistoryReference warnings remain visible. Harness and aggregate-only output are under `/tmp/codex-stats-accounting-check` and `/tmp/accounting-frozen-check.log`.

Synthetic coverage includes independent same-total native histories, differing models/days, duplicate archive and nonempty prefix, usage/owner/model/Turn/time conflicts, physical suffix IDs, empty/damaged streams, legacy/native unprovable overlap, compaction and two different cumulative counters, resolved/missing/out-of-range/mid-record ordinal-byte references, corruption after a valid prefix, real nonempty cycles, empty prefixes, missing/blank owners, rejected malformed foreign IDs, independent valid same-owner legacy counters, and inherited notifications. Logs.scan helper asserts record totals equal global/session/model totals and row identity uniqueness.

## Remaining limits / handoff

Independent check fixed the truncated-compaction-copy false conflict and missing first-source conflict diagnostics, with three added regressions. Final checked code passed **70 Core tests**, native minimum-macOS-14 build and signature verification, and the unchanged frozen 29/6,714/890,273,713 aggregation/cache invariants. Exact commands, initially failing reproductions and review limits are in `check-result.md`; the parent's final same-pass live native audit remains separate.

No real UI clicks, macOS14 hardware or Intel execution was claimed. Independent parent/check audit must verify the live native expenditure oracle and physical history diagnostic transitions before release. Live logs grow; compare totals in a single frozen read, not separate before/after runs.

History references validate local boundaries and coverage; this app reports retained **historical expenditure**, including real requests later reverted, rather than reconstructing the currently projected conversation. Renamed noncanonical physical filenames may leave a reference unresolved but do not discard independently verified owned native responses. Mixed old/new unidentified streams and conflicting native identities stay visibly incomplete rather than guessing a charge. Root UI child should consume diagnostics by severity/kind, group messages, and document the final public report contract; do not classify message strings.
