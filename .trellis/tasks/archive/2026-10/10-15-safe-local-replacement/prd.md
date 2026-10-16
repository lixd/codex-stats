# A06: checked local App replacement

## Goal and authorization

User authorization: the audit report proposed these five work packages; the user then explicitly requested fixing them with Trellis. This is implementation approval following that review, not merely task-creation consent. Scope and ordinary implementation decisions are resolved; no additional approval gate is inferred. Keep prior audit artifacts intact. No user App operation, real-log mutation, install, commit, push or publication. A07 remains deferred.

## Requirements

R14/R17

Own Scripts/build-macos.sh, install-local.sh, minimal system helper(s), isolated delivery tests, docs/development.md and docs/usage.md if needed. Do not edit root product design docs or README without coordination. Reject running bundle, stage and validate then atomically/recoverably replace. Real isolated success/failure tests with own test bundle only. No user App install or termination; do not invoke default installer.

## Acceptance

Use docs/audit-fixes-design.md for observable outcomes. New independent regression expectations pass; existing contracts remain covered. Record current commands and limitations, do not use historical pass results. Keep offline/read-only/zero third-party runtime and no unrequested features.
