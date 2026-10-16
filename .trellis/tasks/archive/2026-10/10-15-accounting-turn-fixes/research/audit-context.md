# Existing audit evidence

Read docs/small-beautiful-audit.md and relevant research under .trellis/tasks/archive/2026-10/10-15-small-beautiful-audit/. These are pre-fix evidence, not this implementation's test results.

Own CodexLogScanner.swift, TokenUsage only in Models.swift, scanner/Turn/request tests and any dedicated accounting tests. First regression failure for replay and invalid subset, then fix, then optimize Turn association preserving all veto evidence. Session APIs in Models.swift belong to another agent: patch only owned sections; do not overwrite its changes. Use full report comparison and complete-Turn scale benchmarks.
