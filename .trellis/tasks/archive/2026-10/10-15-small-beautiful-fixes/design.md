# Technical design

Authoritative approved target: docs/audit-fixes-design.md, written before implementation. Read docs/design.md, requirements.md, data-design.md and ui-design.md.

Own authoritative docs, version metadata, integration verification and final review. Children: accounting-turn-fixes for A01/A02/A03; session-status-fixes for A04/A05; safe-local-replacement for A06. Verify each child and then entire product with exact snapshots and isolated UI/build checks.

No compatibility fallback, persistent cache or framework. Preserve all correctness evidence before optimizing. Capture deviations before implementation in the authoritative design. Parent integrates docs/status/version only after actual tests.
