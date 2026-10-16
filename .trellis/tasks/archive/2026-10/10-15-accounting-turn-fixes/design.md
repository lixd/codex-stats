# Technical design

Authoritative approved target: docs/audit-fixes-design.md, written before implementation. Read docs/design.md, requirements.md, data-design.md and ui-design.md.

Own CodexLogScanner.swift, TokenUsage only in Models.swift, scanner/Turn/request tests and any dedicated accounting tests. First regression failure for replay and invalid subset, then fix, then optimize Turn association preserving all veto evidence. Session APIs in Models.swift belong to another agent: patch only owned sections; do not overwrite its changes. Use full report comparison and complete-Turn scale benchmarks.

No compatibility fallback, persistent cache or framework. Preserve all correctness evidence before optimizing. Capture deviations before implementation in the authoritative design. Parent integrates docs/status/version only after actual tests.
