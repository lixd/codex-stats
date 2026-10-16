# Design-first Development

This is the project contract requested by the user on 2026-10-14. It applies before every product behavior, accounting, UI, state, configuration or lifecycle change.

## Authoritative documents

Read [design baseline](../../../docs/design.md), [requirements](../../../docs/requirements.md) and the linked current UI/data designs. Approved pending targets are separate from implemented behavior. The current source baseline is v0.2.21/build23 with the B menu, D analysis layout, cyan/blue palettes, compact request layout, four-page navigation plus derived cache-rate/reference-USD, effective local price management and model-filtered overview implemented; request-density-design.md overrides the older request geometry, and remove-model-statistics-design.md removes the standalone model page (old model-layout-proposals.md is historical). The approved sequence was fixed cyan plus D verification first, then blue/preferences; see native-cyan-blue-design.md. dashboard-model-filter-design.md defines the current four-card overview, scalar query and explicit new-default import. overview-trend-design.md defines the current three-metric trend and dense/unknown states. Further geometry changes require a separate approved contract. Bootstrap placeholders are not executable contracts.

## Before implementation

1. Create/resume the authorized Trellis task and reference R/T IDs.
2. Update the affected project design first. Describe current behavior, target behavior, rationale and alternatives, data/event contracts, UI geometry and states, lifecycle effects, and verification steps. A purely internal change still documents the relevant implementation contract.
3. Mark the target **approved pending** or **proposed** accurately; user selection of a visual direction does not prove it was shipped or approve unspecified features.
4. Read applicable detailed specs. Resolve contradictions explicitly; do not silently preserve old behavior or replace approved design with current code.
5. Only then implement the documented target. If implementation reveals a necessary design adjustment, update the design before writing that adjustment.

A task-local design is an execution plan; it must not be the only place the product's current contract exists. Keep project docs sufficient for rebuilding without conversation history.

## After verification

Update status/version only when implementation and required checks actually pass. Record command/results and limitations in VERIFICATION.md or the task report. Keep current design declarative; retain abandoned alternatives/history in archived tasks. README links to the design rather than duplicating parameter tables. Archive/record the task using Trellis. Source is managed by Git; do not generate source archives unless explicitly requested.

## Concrete acceptance example

For a menu-width change, first document width, picker inner width, padding, long-name/unknown/error states and close-before-analysis behavior. Then change source; check affected native light/dark previews and lifecycle harness. Static rendering verifies layout only. Do not mark click behavior manually verified unless it was actually tested.

## Documentation-only closeout

Verify facts against source, links against files, and product-file hashes unchanged. Do not rerun/install the App or create a new binary version solely to claim documentation quality. Do not alter real logs, personal memory or unrelated bootstrap tasks.

Public repository README stays concise (at most 70 lines); route usage, statistics and development details through `docs/usage.md`, `docs/statistics.md` and `docs/development.md`. Keep root VERIFICATION.md as the stable evidence entry. Classify upstream development scripts with path-specific Linguist attributes, never relabel their actual language or exclude original product tests merely to change percentages.
