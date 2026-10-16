# Integration and design-first closeout

## Goal and authorization

User authorization: the audit report proposed these five work packages; the user then explicitly requested fixing them with Trellis. This is implementation approval following that review, not merely task-creation consent. Scope and ordinary implementation decisions are resolved; no additional approval gate is inferred. Keep prior audit artifacts intact. No user App operation, real-log mutation, install, commit, push or publication. A07 remains deferred.

## Requirements

R02/R04/R07/R11/R13/R14/R16/R17; T01/T03/T04/T06/T07/T08/T09/T10/T11

Own authoritative docs, version metadata, integration verification and final review. Children: accounting-turn-fixes for A01/A02/A03; session-status-fixes for A04/A05; safe-local-replacement for A06. Verify each child and then entire product with exact snapshots and isolated UI/build checks.

## Acceptance

Use docs/audit-fixes-design.md for observable outcomes. New independent regression expectations pass; existing contracts remain covered. Record current commands and limitations, do not use historical pass results. Keep offline/read-only/zero third-party runtime and no unrequested features.
