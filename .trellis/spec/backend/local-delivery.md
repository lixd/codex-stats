# Safe local App delivery

## 1. Scope / Trigger

Read before changing build/install scripts or local App publication. This helper is development tooling, not a bundled runtime dependency or automatic updater.

## 2. Signatures

- `Scripts/build-macos.sh [OUTPUT_DIRECTORY]`
- `Scripts/install-local.sh [--source BUILT_APP] [--destination TARGET_APP]`
- `Scripts/app-delivery.swift`: `check INFO_PLIST DESTINATION build|install` and `publish STAGED_APP DESTINATION build|install`.

## 3. Contracts

Create unique staging directories on the destination volume. Compile/copy and validate plist identity/version, regular executable and strict code signature before publication. Reject same/nested source/destination, destination symlinks and foreign bundle identity. Build rejects a running destination path; install rejects any live instance with the same bundle ID. Recheck immediately before publication; never terminate user processes.

Publish using Darwin `renameatx_np`: `RENAME_SWAP` for an existing destination, `RENAME_EXCL` for a first publication. Unsupported/cross-volume operations fail without a destructive fallback. On swap the old directory occupies the staging path. Cleanup occurs only after confirmed success; publication/launch failure retains recovery staging. A cleanup failure is distinct from failed publication.

Launch by exact URL via NSWorkspace. Verify returned new PID/launchDate, bundle/executable paths and installed identity/version/hash; an `open` exit status alone is insufficient. Production has no in-process version handshake or lock against external launches. The isolated test fixture independently writes its in-process version/PID receipt. Do not claim power-loss durability or protection against arbitrary external modifications.

## 4. Validation & Error Matrix

| Failure | Required outcome |
|---|---|
| Compile/copy/plist/signature before publication | Old App unchanged |
| Running instance | Refuse; existing PID stays alive |
| Atomic rename rejected | Old destination remains |
| Published but launch unconfirmed | Explicit partial result, old swapped copy retained |
| Interrupted around atomic publication | No delete-copy gap; staging residue may remain |

## 5. Good / Base / Bad Cases

Good: stage a valid v2, atomically swap with v1, launch the exact target and verify identity. Base: build an unsigned source into an ad-hoc signed temporary App before publishing. Bad: remove the old App before compilation/copy, kill an old process, or report a copied App as a verified running version.

## 6. Tests Required

`Scripts/test-app-delivery.sh` uses only temporary directories and unique fixture bundles. Check real compilation/copy/signature failures, hashes preserved, atomic swap/exclusive rename, running guard, launched process receipt and failed-launch recovery. Build the actual product separately into `/tmp` and verify strict signing. Do not run the default installer or lifecycle harness against a user's bundle to test scripts.

## 7. Wrong vs Correct

Wrong: `rm -rf "$APP"; ditto source "$APP"`. Correct: prepare and validate a same-volume stage, check live identity, atomically publish, then distinguish publication and launch outcomes.
