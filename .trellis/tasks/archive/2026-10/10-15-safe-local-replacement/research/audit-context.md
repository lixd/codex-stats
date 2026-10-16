# Existing audit evidence

Read docs/small-beautiful-audit.md and relevant research under .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/. These are pre-fix evidence, not this implementation's test results.

Own Scripts/build-macos.sh, install-local.sh, minimal system helper(s), isolated delivery tests, docs/development.md and docs/usage.md if needed. Do not edit root product design docs or README without coordination. Reject running bundle, stage and validate then atomically/recoverably replace. Real isolated success/failure tests with own test bundle only. No user App install or termination; do not invoke default installer.
