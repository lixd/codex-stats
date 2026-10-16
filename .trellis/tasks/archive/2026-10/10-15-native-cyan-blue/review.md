# Independent review — native D / cyan and blue

2026-10-15. Reviewed the task PRD/design/implementation plan, all check.jsonl references, actual production paths and task-start hashes. Scope is this task's changes, not the previously dirty accounting/delivery work. No user App or real logs were opened, replaced or terminated; no commit/push.

## Findings (fixed)

- File: `Tests/MenuDesignPrototype/main.swift:7,79`
- Issue: Changing production CPTheme from Color constants to an environment-resolved ShapeStyle left the historical native menu-preview caller storing CPTheme in a Color tuple and mixing Color/CPTheme in a conditional. `Scripts/render-menu-designs.sh` compiles this caller, so it also needs the new shared interface.
- Fix: Store the tuple as CPTheme and erase the mixed stroke styles with AnyShapeStyle. Two-line mechanical API adaptation; no prototype geometry or product behavior changes.
- Verification: The full menu-prototype dependency set type-checks for arm64 macOS 14. The prototype renderer was not run and its historical screenshots were not regenerated or claimed as new UI evidence.

## Findings (not fixed)

No additional confirmed product defect found in this task's source changes. No product code was changed by this review.

- Documentation closeout remains with the parent: when reviewed, visual-system.md still described v0.2.12 dynamic NSColor/static Color and prohibited a theme preference. This contradicts the approved two-palette target until its planned baseline/spec sync. Parent was notified; reviewer did not edit parent-owned docs.
- Evidence boundary: the successful same-host harness changes Store.palette and edits native text fields, checks search results/request table selection, retained unsaved path/cache/time and rendered Dashboard/Menu pixels. At review time it does not prove actual menu Picker actions, non-default sort/model-filter persistence, a deliberately changed session selection, sheet opening/Escape, activation-state button tint, mouse/keyboard/VoiceOver, real system high contrast or long residency. Source paths preserve the same view identities; that is evidence distinct from exercising these interactions. Parent is extending checks where practical and will record remaining manual checks.

## Checked paths and rationale

- `Sources/App/Appearance.swift:3–61`: exactly two palette values; fixed role table, scheme/contrast from EnvironmentValues, no mutable global theme or UserDefaults access in resolution. Explicit action-fill role protects white text; increased-contrast chart resolves to accent.
- `Sources/App/DashboardView.swift:65–69` and `MenuPanelView.swift:146–150`: environment is injected outside the drawing tree from their shared ObservableObject; status sheet explicitly receives the current palette. No `.id(palette)` or replacement root.
- `Sources/App/SessionsContent.swift:221–274`: Settings reads the injected environment using @Environment(\.self), resolves its Color-only action tint in body, and binds its single palette Picker directly to the shared Store. No onChange/onAppear scan was added. Existing editing-path state remains at the same structural identity.
- `Sources/App/UsageStore.swift:80–82,134–143`: palette didSet only persists its raw value; initialization handles absent/unknown preference as specified. No added timer/Task/refresh/root/cache side effect. Summary-identity and publication tests exercise both palette changes and restoration.
- D geometry, continuous metric strip, model Table native ownership, explicit unknown values, true session identity and full model details agree with the approved target. Native cyan overview and blue Settings same-host PNGs inspected; no visual regression identified there. Remaining screenshots are the parent's verification responsibility.
- Task-start hash comparison confirms Core, Report and AppLifecycle remain unchanged. New Appearance.swift is intentionally App-only; standalone formatter/Store scripts explicitly include it. Existing wildcard App/build/preview entry points discover it automatically.

## Verification

- Lint: PASS — `git diff --check` (no configured Swift linter found).
- TypeCheck: PASS — all Core/App sources, `-target arm64-apple-macosx14.0`; also the full menu-design prototype dependency set. Initial default clang module-cache access was sandbox-denied; rerun with a dedicated writable `/tmp` module cache passed without source workaround.
- Tests: PASS — independently reran `Scripts/test-usage-store.sh` and `Scripts/test-token-display.sh` (en_US/zh_CN/fr_FR).
- Core/menu lifecycle/full preview/build: not independently rerun by this reviewer; the parent owns their current evidence and final gate.
- Logs: `/tmp/codex-stats-native-cyan-blue-20261015/validation/check-{store,format,typecheck,menu-prototype-typecheck}.log`.

No unresolved blocking product finding. Final status remains conditional on the parent's ongoing preview/build and documentation closeout.

## Final closeout review

Rechecked the final task verification, current design/UI/requirements, usage/development docs and visual-system spec after the parent's final gate. The new evidence correctly separates Store-binding/native text-field operations from unperformed Picker/filter/sort/sheet/mouse/VoiceOver interactions. No unsupported performance or memory claim was found. Manually counted each final palette directory: 120 PNGs, including 32 same-host switch images. Both final preview logs end in PASS; final-core.log records 133 passing tests. The final binary SHA256 independently matches `daf704d1b2c6d774eedcaa20ba264d1701458aeda41cd9f46d3499f8625eb9ef`.

Three remaining current-baseline text inconsistencies were sent to the parent for its final documentation pass: docs/design.md lifecycle version row still v0.2.12/14, requirements R17 still broadly says the layout is deferred, and design-first.md still gives the old v0.2.12/deferred baseline. The Sage paragraph in ui-design.md was also flagged and is now explicitly historical. These are documentation closeout items, not product-code changes. No additional product defect found; no product edits made during this final pass.
