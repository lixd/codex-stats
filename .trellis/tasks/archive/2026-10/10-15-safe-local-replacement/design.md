# Technical design

Authoritative approved target: docs/audit-fixes-design.md, written before implementation. Read docs/design.md, requirements.md, data-design.md and ui-design.md.

Own Scripts/build-macos.sh, install-local.sh, minimal system helper(s), isolated delivery tests, docs/development.md and docs/usage.md if needed. Do not edit root product design docs or README without coordination. Reject running bundle, stage and validate then atomically/recoverably replace. Real isolated success/failure tests with own test bundle only. No user App install or termination; do not invoke default installer.

No compatibility fallback, persistent cache or framework. Preserve all correctness evidence before optimizing. Capture deviations before implementation in the authoritative design. Parent integrates docs/status/version only after actual tests.
