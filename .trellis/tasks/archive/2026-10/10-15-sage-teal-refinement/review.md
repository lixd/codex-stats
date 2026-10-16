# Independent Trellis review — Sage + Teal

2026-10-15. Source review: **PASS; no confirmed new product defect found**. This review did not change product source or repeat the main session's expensive checks. Documentation promotion remains the main session's final closeout step.

## Findings (fixed)

None. No product source was edited by the reviewer.

## Findings (not fixed)

No confirmed issue in the approved implementation needs a product fix. The following are evidence limits or deliberately deferred work, not new defects:

- Actual system increased-contrast switching/repaint, mouse and keyboard table use, clipboard, sheet Escape and VoiceOver were not exercised by this review. The SDK's `NSAppearance.h:73–79` explicitly reserves high-contrast names for `bestMatchFromAppearancesWithNames:` and says `appearanceNamed:` returns NULL. The provider uses the supported matching API (`Sources/App/Components.swift:40–55`); ordinary light/dark captures and mathematical border swatches must not be called real high-contrast verification. Do not alter the user's system preference merely to fill this acceptance gap.
- Existing A07 request inspector/narrow-window geometry remains outside the palette task. Native horizontal scrolling is retained; the static 1120-point inspector image shows a narrower table viewport as expected. This review does not claim actual horizontal mouse/trackpad scrolling was tested. No custom grid, estimated table height or extra scrolling container was introduced.
- Before promoting the baseline, the main session must replace the old color/opacity/trend entries in `docs/ui-design.md`, update baseline/version references and `VERIFICATION.md`, and add the scoped frontend visual contract. At review time those documents correctly still marked the new design approved pending; this is a remaining closeout action, not authorization to preserve contradictory old parameters as current behavior.

## Review evidence

- Read `check.jsonl` and all five referenced contracts, task PRD/design/implementation plan, `docs/design.md`, `docs/sage-teal-design.md`, frontend index and quality/type placeholders. `get_context.py --mode packages` confirms a single repository with frontend/backend spec layers. Placeholder lint/type prose was not treated as an implemented tool contract.
- Compared every file listed in `start-hashes.json` against its current SHA-256. Only five intended App presentation files, `Assets/Info.plist`, the native preview harness and three product design/requirement documents changed among the recorded inputs. Core, report CLI, `UsageStore`, `AppLifecycle`, delivery scripts, numeric formatter harness and existing Core tests match their task-start hashes. The full Git diff also contains prior uncommitted audit fixes and was not treated as this task's change scope.
- `CPTheme` has ten static dynamic roles and one appearance provider; no observable theme model, timer, task, preference or per-record color allocation was added. Light/dark values match the approved design. Separate `actionFill` preserves white-label contrast in dark mode (`Components.swift:28–38`, `MenuPanelView.swift:122–124`, `SessionsContent.swift:240–242`). The app does not apply a global custom tint to native controls.
- Dashboard/sidebar/page/surface roles and teal chart/legend/rank roles are consistent. Warning icon and text remain separate from normal status. Information-only diagnostics use the approved opaque selection fill (`Components.swift:298–305`), avoiding a low-contrast accent-on-translucent-accent pairing.
- Model view still uses the same real `Table(rows)` and existing columns, with `.inset(alternatesRowBackgrounds: false)` and native scroll ownership (`DashboardView.swift:393–414`). Requests retain native selection, scrolling and inspector state; only presentation wrappers/header fill change in this task (`RequestsContent.swift:104–113`, `158`). Sessions retain the bulk precomputed query introduced by the earlier audit; this task adds selected accessibility traits and role backgrounds/borders (`SessionsContent.swift:53–67`, `117–120`).
- Preview assertions inspect real `NSTableView.numberOfRows`, `usesAlternatingRowBackgroundColors` and `enclosingScrollView`, then actually scroll an 80-row native table to its last row and back (`Tests/UIPreview/main.swift:305–347`). These assert behavior beyond copying palette constants. Synthetic scan failures/recovery continue through the real Store/scanner. Exact expected RGB checks are design regression checks; contrast and native table assertions provide independent acceptance evidence.
- Inspected six actual current native captures: `models-1120-light.png`, `overview-dark.png`, `status-warning-rectangle.stack-light.png`, `inspector-1120-light.png`, `requests-950-dark.png`, `menu-dark.png`, under `/tmp/codex-stats-sage-teal-20261015/previews`. Sparse models have no decorative empty zebra rows; layers, selection outline, unknown fields, distinct warnings and dark white-label action remain visible. This was not an inspection of every generated PNG and is not live interaction proof.

## Verification

- Lint: no dedicated repository Swift linter is configured; independent `git diff --check` **PASS**. No linter installation was attempted.
- TypeCheck/build: **PASS**, inspected the main session's current optimized native build and SwiftPM App compilation evidence. The product is v0.2.12/build14, arm64, deployment target macOS14.0, strict signature verification exit0, system-only linked dependencies. Evidence: `/tmp/codex-stats-sage-teal-20261015/build-final.log` and `validation/product.json`. This does not prove execution on macOS14 or Intel.
- Tests: **PASS**, inspected current main-session logs:133 Core tests/0 failures (`validation/core-final.log`), real Store (`validation/store.log`), UUID menu lifecycle harness (`validation/menu-retry.log`), and final native preview (`preview.log`, 88 PNGs). Formatter 16 cases across three locales is recorded in task verification and `/tmp/codex-stats-sage-teal-20261015-token.log`; no historical audit benchmark is reused as new palette performance evidence.
- Current dynamic color evidence: `previews/theme-contrast.txt` verifies both actual ordinary appearances, with role text contrast minimum4.511:1, white/action4.563:1, risk fill minimum4.858:1, intended high-contrast border swatch minimum3.660:1. Native system text and native controls remain system-managed; these numbers do not certify every rendered glyph or active native table selection.
- Verified no user App install, quit or replacement, no real-log writes, no commit or push were performed by this reviewer. Product source remained read-only during review; only this report was added.

## Final documentation consistency follow-up

Final read-only follow-up after the main session's baseline promotion: **PASS**. This closes the documentation action recorded above; no additional product source fix or test rerun was needed.

- `docs/design.md`, `docs/requirements.md` and `docs/ui-design.md` now identify source v0.2.12/build14. Data design remains explicitly the unchanged v0.2.11 accounting contract; prior A01–A06 evidence is kept as versioned history.
- Current UI reconstruction entries now use the actual dynamic page/section/card/selection/action roles, accent trends, native unstriped model table and selected session border/trait. Menu B's production table retains v0.2.10 geometry while using selection, accent information text and actionFill; its prototype captures remain identified as history.
- `docs/sage-teal-design.md`, `.trellis/spec/frontend/visual-system.md`, frontend index and design-first baseline agree with current source. Actual system increased contrast, VoiceOver, user interaction and macOS14/Intel limits remain explicit rather than promoted to tested behavior.
- `VERIFICATION.md`, task verification and copied evidence logs preserve this round's133 Core/formatter/Store/menu results,88 native PNGs, contrast values and optimized product identity. They do not claim new memory/performance measurements or user App replacement.
- Independent `git diff --check` remains **PASS**. No expensive test repeats, App launch/quit, source mutation, commit or push were performed in this follow-up. Main session retains ownership of final link checks, archive path updates and no-commit closeout.
