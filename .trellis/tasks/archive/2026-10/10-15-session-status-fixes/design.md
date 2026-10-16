# Technical design

Authoritative approved target: docs/audit-fixes-design.md, written before implementation. Read docs/design.md, requirements.md, data-design.md and ui-design.md.

Own App views/store, non-TokenUsage session/report/date APIs in Models.swift, DateFilteringTests, Tests/UsageStore and Tests/UIPreview. Another agent owns TokenUsage at top of Models.swift: patch only owned sections. Add operation-local projection, one final sort, shared header status and sheet; preserve selection and current menu navigation. Test date boundaries, active empty sessions, error preservation/info/recovery, previews.

No compatibility fallback, persistent cache or framework. Preserve all correctness evidence before optimizing. Capture deviations before implementation in the authoritative design. Parent integrates docs/status/version only after actual tests.
