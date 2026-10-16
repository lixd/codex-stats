<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

# Document-driven development

- Read `docs/design.md` before every product change; it is the reconstruction baseline and links to UI/data contracts and approved pending designs.
- Before implementation, update `docs/requirements.md` and the affected design document with the intended behavior, rationale, state/data/layout contracts, and acceptance checks. Record the change in a Trellis task referencing R/T requirement IDs. Do not leave the design update until after coding.
- Keep **implemented baseline** separate from **approved pending** work. The B menu remains implemented; `docs/ui-design-b.md` preserves its structure. The current v0.2.21 analysis window uses D layout with cyan/blue colors; `docs/native-cyan-blue-design.md`, `docs/request-density-design.md`, `docs/model-layout-proposals.md` and `docs/ui-design.md` are the current contracts; `docs/cache-rate-cost-design.md` adds the derived cache-rate and reference-USD contract; `docs/model-price-management-design.md` extends it with the effective local price catalog, all-history candidates and guarded deletion. `docs/dashboard-model-filter-design.md` defines the current overview cards, local model filtering and explicit new-default price import. `docs/remove-model-statistics-design.md` removes the standalone model statistics page; retain only overview, requests, sessions and settings. Model aggregation/filtering/pricing remains. `docs/overview-trend-design.md` defines Token/record-count/API-equivalent USD trend modes and dense/unknown states. Further layout changes require their own design and verification.
- When code and design disagree, report and resolve the discrepancy explicitly. Existing code is evidence for documenting current behavior, not authorization to override an approved design.
- After verification, update implementation status, baseline version and evidence links. Do not claim static previews prove live interaction, or unexecuted checks passed.
- Workflow details: `.trellis/spec/guides/design-first.md`. Preserve the managed Trellis block above.
