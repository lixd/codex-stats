# A01/A02/A03: accurate accounting and efficient Turn attachment

## Goal and authorization

User authorization: the audit report proposed these five work packages; the user then explicitly requested fixing them with Trellis. This is implementation approval following that review, not merely task-creation consent. Scope and ordinary implementation decisions are resolved; no additional approval gate is inferred. Keep prior audit artifacts intact. No user App operation, real-log mutation, install, commit, push or publication. A07 remains deferred.

## Requirements

T01/T03/T04/T06/T07/T08/T09/T10/T11; R13/R16

Own CodexLogScanner.swift, TokenUsage only in Models.swift, scanner/Turn/request tests and any dedicated accounting tests. First regression failure for replay and invalid subset, then fix, then optimize Turn association preserving all veto evidence. Session APIs in Models.swift belong to another agent: patch only owned sections; do not overwrite its changes. Use full report comparison and complete-Turn scale benchmarks.

## Acceptance

Use docs/audit-fixes-design.md for observable outcomes. New independent regression expectations pass; existing contracts remain covered. Record current commands and limitations, do not use historical pass results. Keep offline/read-only/zero third-party runtime and no unrequested features.
