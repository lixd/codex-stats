# Current audit evidence — 2026-10-15

Baseline HEAD: `11f2a937971c40b29a2b4d69ff6bb79c5eaec91f`; v0.2.10/build12. Only review artifacts are changed. Product-file inventory is in `product-baseline.json` (41 files). All workload inputs were synthetic. No user App installation, termination, replacement, real-log mutation, commit or push.

## Executed checks

| Execution | Evidence | Result and limits |
|---|---|---|
| `./Scripts/test.sh` | [core-tests.txt](evidence/core-tests.txt) | 121 tests passed, 0 failures; current App target compiled; existing CLT linker warnings retained |
| `./Scripts/test-usage-store.sh` | [store-tests.txt](evidence/store-tests.txt) | Current scanner states, old-result preservation, summary identity/invalidation and unknown semantics passed |
| `./Scripts/test-token-display.sh` | [display-tests.txt](evidence/display-tests.txt) | 3 locales × 16 numeric boundaries plus shared/unknown/exact checks passed |
| `./Scripts/test-menu-lifecycle.sh` | [menu-lifecycle.txt](evidence/menu-lifecycle.txt) | Own uniquely identified AppKit harness only; exact owned window, replacement, resident policy and explicit termination; not production menu clicks |
| `./Scripts/render-ui-previews.sh /tmp/codex-stats-audit-20261015/previews` | [previews.txt](evidence/previews.txt) | Current production views, synthetic logs; no screen capture, no real clicks |
| Supplemental copied preview harness | [supplemental-previews.txt](evidence/supplemental-previews.txt) | Added sessions/narrow overview and successful-report-then-failure models/sessions; code generation preserved in research/prepare-ui-preview.py |
| `./Scripts/build-macos.sh /tmp/codex-stats-audit-20261015/build` + strict codesign | [build.txt](evidence/build.txt) | Current arm64 build; no open/install command printed by script was executed |
| `sw_vers`, Swift version, sysctl, vtool, otool | [environment.txt](evidence/environment.txt) | macOS27.0.1, Swift6.4, arm64 8-core/8GiB; minOS14 target; system libraries only |
| Original fixed synthetic benchmark + two same-binary fresh-process runs | [first stdout](evidence/benchmark1.txt), [run2](evidence/audit2.txt), [run3](evidence/audit3.txt) | 39 files/349,964,213 bytes/7,020 rows/9,043,780 Tokens; all harness accounting invariants passed |
| Full snapshot comparison after the 3 standard runs | Task command output: `PASS: three fresh-process exact accounting snapshots agree` | Parsed JSON equality of rows/identity/order/model/session/day/hour/diagnostics/four periods; same source, not pre/post optimization |
| New accounting counterexamples, independent direct compilation | [agent output](research/accounting-actual.json), [analysis](research/accounting.md) | 7 cases; replay total110→220 and impossible subset delta known10 confirmed; execution success is not product correctness |
| Same cases against freshly built `.build/debug/codex-stats-report` | [crosscheck](evidence/accounting-crosscheck.json) | Exact normalized JSON equality with independent direct release compilation |
| Release scale harness | [results](evidence/scale-results.jsonl), [manifest](evidence/scale-manifest.json), [resource output](evidence/scale-memory.txt) | 250/500/1000/2000 complete Turns; 1k/5k session projections; strict token/identity/timing invariants |
| Same 2000 native responses without completion events | [control](evidence/control-results.jsonl), [manifest](evidence/control-manifest.json) | Tokens unchanged; performance nil as expected; warm median9.63ms; original complete warm4.368s |
| `measure-app-memory.sh` using built App and same synthetic fixed input | [summary](evidence/app-memory.txt), [10s vmmap](evidence/app-memory-10s.txt), [35s vmmap](evidence/app-memory-35s.txt) | Own copied UUID bundle only; current25.8M/27.2M, lifetime peak30.3M/34.8M; sandbox-extension warning retained; process survived and only test instance terminated |

The standard benchmark metrics/resources are saved as `evidence/audit{1,2,3}-{metrics.json,memory.txt}`. Median cold2.918s/warm63.35ms/append127.34ms. One warm is100.02ms, so only2/3 meet a strict100ms bound. Largest/smallest max RSS and peak footprint are separate; neither is current App RAM. The scale resource file covers all harness cases and retained verification objects, not one case or a production App.

Selected image evidence (only synthetic content): [narrow inspector](evidence/inspector-950-light.png), [model warnings gap](evidence/models-950-light.png), [failed-refresh model](evidence/audit-failed-refresh-models-light.png), [sessions](evidence/audit-sessions-950-light.png), [B menu](evidence/menu-dark.png). Parent inspected these plus narrow dark overview; other generated states are execution coverage, not a claim that every screenshot received manual inspection.

## Reproduction from repository root

Use a new temporary output directory for each run. No external dependencies are installed. Compiled source paths below remain production files; only review harnesses are additional.

```sh
AUDIT_TASK=.trellis/tasks/archive/2026-10/10-15-small-beautiful-audit
AUDIT_WORK=$(mktemp -d /tmp/codex-stats-review.XXXXXX)

# Correctness counterexamples; prints actual vs expected, does not claim PASS.
python3 "$AUDIT_TASK/research/accounting-repro.py"

# Standard workload: own generated fixture includes a controlled append/restore.
./Scripts/benchmark-performance.sh "$AUDIT_WORK/standard" Sources/Core current

# Complete-Turn scaling and underlying session computation, not UI frame time.
python3 "$AUDIT_TASK/research/generate-scale.py" "$AUDIT_WORK/scale"
xcrun swiftc -O -swift-version 5 -parse-as-library Sources/Core/*.swift \
  Sources/App/UsageStore.swift "$AUDIT_TASK/research/scale-probe.swift" -o "$AUDIT_WORK/scale-probe"
/usr/bin/time -l "$AUDIT_WORK/scale-probe" "$AUDIT_WORK/scale"

# Control with unchanged native responses but no completed-Turn association.
python3 "$AUDIT_TASK/research/generate-scale.py" "$AUDIT_WORK/control" \
  --counts 2000 --without-completion
/usr/bin/time -l "$AUDIT_WORK/scale-probe" "$AUDIT_WORK/control" --skip-projections

# Extra static native states; the copied script owns its generated root.
python3 "$AUDIT_TASK/research/prepare-ui-preview.py" "$PWD" "$AUDIT_WORK/preview-harness"
bash "$AUDIT_WORK/preview-harness/render.sh" "$AUDIT_WORK/previews"
```

Current script generation was checked against the supplemental harness actually executed (Swift source and runner-equivalent paths). Parent benchmarks were serial, not parallel with parent compilations. Other host workload was not pinned or disabled; no disk-cache purge. All wall-clock results are scoped to this machine and workload.

## Independent review and exclusions

- Accounting, performance and UI agents each recorded research; accounting/performance cross-reviewed remediation semantics. Parent repeated accounting against a separate current CLI binary and inspected screenshots/source.
- Do not optimize away foreign/missing owner/Turn/time, unmatched counters, inherited-prefix or corrupt-history uncertainty. Turn pairing must retain `inherited: 0` and OR semantics for frameRange/Turn/time/unknown-time relevance.
- No new claim of live production menu interaction, duplicate production-instance execution, clipboard/keyboard/VoiceOver success, sleep/wake or long-term stability. Existing tests and renderers do not cover those actions.
- No current true-log accounting audit, new DMG/source ZIP, target-macOS14/Intel run, Developer ID or notarization. These limits remain explicit in the report.
- No product spec changes: this task contains findings and proposals, not approved replacement contracts. Next work awaits user scope selection and design-first updates.

Final artifact scope, link/hash/HEAD checks and task disposition are recorded in `check-result.md`.
