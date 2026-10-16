# A04/A05: session projection and shared status

## Goal and authorization

User authorization: the audit report proposed these five work packages; the user then explicitly requested fixing them with Trellis. This is implementation approval following that review, not merely task-creation consent. Scope and ordinary implementation decisions are resolved; no additional approval gate is inferred. Keep prior audit artifacts intact. No user App operation, real-log mutation, install, commit, push or publication. A07 remains deferred.

## Requirements

R02/R04/R07/R11/R13; T06/T08

Own App views/store, non-TokenUsage session/report/date APIs in Models.swift, DateFilteringTests, Tests/UsageStore and Tests/UIPreview. Another agent owns TokenUsage at top of Models.swift: patch only owned sections. Add operation-local projection, one final sort, shared header status and sheet; preserve selection and current menu navigation. Test date boundaries, active empty sessions, error preservation/info/recovery, previews.

## Acceptance

Use docs/audit-fixes-design.md for observable outcomes. New independent regression expectations pass; existing contracts remain covered. Record current commands and limitations, do not use historical pass results. Keep offline/read-only/zero third-party runtime and no unrequested features.
