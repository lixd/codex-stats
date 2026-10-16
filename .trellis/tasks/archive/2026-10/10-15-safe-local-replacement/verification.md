# A06 implementation verification

Date: 2026-10-15. Scope: R14/R17, approved `docs/audit-fixes-design.md`. No production App was installed, replaced, launched or terminated. No real logs were used. No staging, commit or push. Shared product docs/version/final App build remain parent-owned.

## Changes

- `Scripts/build-macos.sh`: unique same-volume stage; compile/resources/signature before publication; refuse a running destination; preserve prior build on failure.
- `Scripts/install-local.sh`: optional explicit source/destination for isolated delivery; compile the checker in independent system temporary storage, then validate paths/identity/running state before writing to the destination parent. Only afterward create the same-volume bundle stage. Default build stays inside this stage instead of publishing to dist; reject any running matching bundle again immediately before publication. Checker cleanup and recoverable bundle-stage retention are independent.
- `Scripts/app-delivery.swift`: system-only development helper, excluded from App runtime. Validate complete metadata/executable/strict signature; reject symlink targets, foreign identities, same/ancestor paths. `renameatx_np(RENAME_SWAP)` retains prior bundle at staging path; `RENAME_EXCL` publishes an absent destination. No delete-copy fallback.
- Exact-path LaunchServices opening verifies callback PID, launch time, bundle/executable URL and installed metadata/SHA256 before reporting launch success. Failed launch is reported distinctly after publication; the old bundle remains at the printed stage path. Cleanup errors are separate warnings and do not imply rollback.
- `Tests/Delivery` and `Scripts/test-app-delivery.sh`: UUID native fixture App with an in-process version/path/PID receipt and normal termination controller restricted to fixture identifiers. Real filesystem/compiler/ditto/codesign/LaunchServices operations, no success mocks.
- `docs/development.md` and `docs/usage.md`: behavior, source/destination options, recovery and verification limits.

## Current results

1. Native helper compilation and missing-destination preflight passed.
2. Final `./Scripts/test-app-delivery.sh` after independent-review repair: **18 checks passed**, including actual v1 → v2 replacement and in-process receipt. [Full log](evidence/delivery-tests.txt).
   - Corrupt signature, missing executable, incomplete metadata and foreign identity reject with unchanged previous bundle digest.
   - `ditto` really fails on an unreadable fixture resource; prior bundle unchanged.
   - Target symlink and same source/target rejected. Nested target rejection leaves both full source digest and directory modification time unchanged, including preparation; a SIGKILL of the independent installer process group during preparation also leaves the source untouched.
   - A minimal checkout invokes the production build script with a real Swift syntax error; previous signed fixture remains byte/mode-identical.
   - Real atomic swap verifies candidate at target and exact previous bundle at source; first publication verifies exclusive rename.
   - Actual installer copies, validates, swaps and starts the exact UUID target. Fixture-reported PID/path/version/build match expected v2 and helper output.
   - A running target, same UUID running elsewhere and build destination guard all reject; original PID stays alive. Only fixture controller later exits it normally.
   - New fixture intentionally exits at startup: installer fails truthfully with “published but launch unconfirmed”; exact previous bundle survives at reported recovery path.
3. Earlier focused `python3 Tests/Delivery/test_delivery.py --interruption-only`: **passed**, recorded in [interruption log](evidence/interruption-test.txt), and also passed in the final complete 18-check run. It signalled only a separate fixture build process group after staged Info.plist appeared and before publication; target digest remained unchanged and the temporary stage survived. No App process was signalled.
4. Baseline `11f2a937971c40b29a2b4d69ff6bb79c5eaec91f` build script was run in an isolated minimal checkout against a previous-build marker, with the same real Swift syntax failure. It removed the marker (exit 1), reproducing the prior deletion-before-compile problem. [Evidence](evidence/baseline-compile-failure.txt). This is a filesystem artifact-loss reproduction, not a claim that a user App failed.
5. Shell syntax and scoped tracked whitespace checks passed. Test Python parsed successfully. No test fixture process remained after normal cleanup.

The first development test failed because Foundation normalized the fixture path as `/var/folders` while Python resolved it as `/private/var/folders`; actual identity/PID/version already matched. The oracle now resolves both sides. This failed development attempt was not counted as a passing run. The final successful replacement test explicitly restores v1 before installing v2.

## Independent-review repair

The original nested-path check ran after destination-parent preparation. A source-relative nested destination could therefore receive temporary files before rejection, even though cleanup restored its content digest. The new regression first failed against that implementation: the protected App's directory mtime changed while the digest stayed equal ([before](evidence/preflight-before.txt)). Installer helper compilation now uses a unique `/tmp` directory, and all target-parent writes follow successful preflight. Checker temporary storage is always cleaned separately; publication failures still retain the same-volume stage containing the old App.

`python3 Tests/Delivery/test_delivery.py --preflight-only` passed both the no-transient-write rejection and forced-interruption cases ([after](evidence/preflight-after.txt)); the final 18-check run passed them again alongside all replacement/launch/failure checks. Only the owned shell/compiler process group was signalled, not an App process. No shared product design/version/spec files were changed during this repair.

## Boundaries and remaining acceptance

- The installed SDK's `rename(2)` documents atomic `RENAME_SWAP` and exclusive `RENAME_EXCL`. Actual same-volume operations passed on this host. Unsupported/cross-volume failure has no fallback; other filesystems were not mounted/tested.
- SIGKILL before publication is tested separately; no power loss, kernel interruption inside rename, filesystem durability or automatic recovery daemon is claimed. A crash may leave a stage for manual inspection.
- Production launch validation is process/path + installed artifact verification, not a runtime version handshake. The fixture's runtime receipt independently verifies this test, but no new IPC was added to Codex Stats. Separate user launches can race with checks; this is not a system-wide lock.
- macOS 27.0.1 / arm64 only. macOS 14, Intel, Developer ID, notarization, DMG installation and production App interaction remain unexecuted here.
- Parent must perform integrated product build and independent review after all agents stop native compiles. No default installer invocation occurred.


## Final integration handoff

Parent completed the final 133-test suite, 126-case differential, fixed-input accounting/scale verification, optimized native build, isolated lifecycle and App footprint checks. See [integration evidence](../10-15-small-beautiful-fixes/verification.md). Child-local statements that parent integration was pending describe the earlier handoff. Native clicks/Esc remain explicitly unverified because the Mac is locked. No production App operation or commit occurred.
