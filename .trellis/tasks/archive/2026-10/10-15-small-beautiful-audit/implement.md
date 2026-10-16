# Audit execution plan

1. [x] Read repository instructions, Trellis workflow, design, requirements, UI/data contracts and verification history. Verify current HEAD and clean state.
2. [x] Activate review task and save product-file SHA-256 inventory. Delegate three read-only review tracks with bounded ownership.
3. [x] Trace runtime/data flow; inspect test and delivery scripts for side effects before execution.
4. [x] Run current Core/store/format/lifecycle checks that do not operate on the user's instance. Reproduce strongest suspected defects with synthetic fixtures.
5. [x] Run controlled release benchmarks serially. Cover unchanged refresh, growth and high record counts; record environment, inputs, accounting invariants and metric definitions.
6. [x] Inspect current native synthetic previews at narrow/wide/light/dark conditions. Mark unexecuted interaction/accessibility/platform checks explicitly.
7. [x] Cross-review candidates, remove duplicates/shipped fixes, write docs/small-beautiful-audit.md and evidence notes.
8. [x] Validate links, artifact scope, unchanged product hashes/HEAD. Retain/close Trellis review record without commits or pushes; product work awaits user scope confirmation.
