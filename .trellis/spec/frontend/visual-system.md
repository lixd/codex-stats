# Native visual roles

## Scope and implementation

Read before changing Appearance.swift/CPTheme, dashboard surfaces, native Tables or selected session cards. Current source is v0.2.20/build22. Exact roles and D geometry are in [D with cyan/blue](../../../docs/native-cyan-blue-design.md) and [UI baseline](../../../docs/ui-design.md). Sage + Teal is historical v0.2.12 evidence, not a third selectable palette.

Appearance.swift contains exactly two AppPalette values, cyan (default) and blue. CPTheme is a ShapeStyle enum; resolve(in:) derives a concrete Color from the local environment's appPalette, colorScheme and colorSchemeContrast (macOS14+). No global mutable palette, NSColor provider reading defaults, polling, per-record colors or root .id(palette). Mixed role/native-color expressions use AnyShapeStyle. Keep native primary/secondary text and the system/user control accent. Only the app-owned prominent save action resolves actionFill to Color for tint; do not apply global tint.

UsageStore.palette persists only to its injected UserDefaults, key CodexStatsColorPalette. Missing/unknown stored values default cyan. Its didSet must not refresh, reconfigure timers, clear reports/summary or change root/range. Dashboard/Menu root environment modifiers observe the same Store; sheets explicitly receive the selected palette. Preserve view identity and all local search/sort/filter/selection/path-draft states.

Use page for content ground, section for sidebar/session list, header for the near-white header, metric for the continuous four-item strip, card for content/Table grounds, selection for selected navigation/session/menu total and information diagnostics. chart is deliberately pale; increased contrast uses accent. Use actionFill for white-label solid actions: the bright dark-mode text accent fails white-text contrast. Risks keep orange plus words and symbols; unknown values and retained errors stay explicit.

## Four sections and native scrolling

R22 removes the standalone ModelsContent/ModelUsageGroup page and its private search/sort UI. DashboardSection has exactly overview, requests, sessions and settings, default overview. Do not restore the old page from historical model-layout-proposals.md. See [removal contract](../../../docs/remove-model-statistics-design.md). Core model aggregation, overview exact-model filter/distribution/details, request filtering, session model details and Settings price management remain.

Requests retain native Table, alternating rows and selection, owned scroll view, card background/border. Do not wrap them in a custom grid or an extra horizontal ScrollView. Session selection retains opaque selection fill, accent border and isSelected trait.

## Request density and fit

Request header is one row (16/12 padding); its PeriodPicker lives beside record count. Content16/12 with8pt gaps. Native Table uses10 columns for outer table width>=900pt,7 below it; pair model/evidence, uncached/cache and duration/speed without losing fields. Reserve legacy vertical-scroller width as well as native17pt intercell spacing; summing `.width` values is not a fit proof. Current exact widths are in request-density-design.md. Do not hide horizontal scrollbars to conceal overflow. Details use the same420×600 native sheet renderer; selection is the only presentation state and close clears it, retaining queries/sort/filter.

Paired Text with `.accessibilityLabel("缓存输入")` also needs `.accessibilityValue(detailedNumber(..., known: ...))`, otherwise the spoken numeric/unknown value is replaced. Verify actual NSView geometry at950,1050 and1116/1117/1118/1120/1280, including test-only `.legacy` scrollers; require the Table to exist instead of optional lookup that silently skips assertions. Assert document<=clip, final column visible,80 real rows and final-row reach. Static root images cannot prove sheet presentation: use a real NSHostingController parent, explicit setContentSize, and assert a native `isSheet` window with `sheetParent === ownWindow`. Virtual AX controls may be unavailable in an offscreen host; do not claim production close/Escape/VoiceOver passed from AppKit endSheet cleanup.

## Appearance and state verification

Run Scripts/render-ui-previews.sh <unique temporary output> cyan, then a separate output with blue. All logs/defaults are synthetic/isolated. The harness resolves the same production roles in both palette/scheme environments, checks exact sRGB values, accent/input/output/risk on every opaque role, white/actionFill and composited risk fills. Ordinary custom text must reach4.5:1. Check changed alpha fills too; information diagnostics use opaque selection.

The same-host test edits real native NSTextFields for requests/sessions/settings, switches Store.palette cyan→blue→cyan, and checks dashboard/menu encoded background pixels, query/filter results, selected request row, path draft, summary identity and unchanged successful refresh time. It does not replace rootView. This is programmatic native-control evidence, not mouse, VoiceOver, nondefault model/sort Picker selection, non-first session selection or open-sheet interaction evidence. SwiftUI menu Pickers are not NSPopUpButton in this host; do not weaken tests or claim a failed lookup passed.

cacheDisplay's bitmap reports calibrated RGB storage containing the rendered encoded channels; comparing them to role channels avoids an extra calibrated→sRGB transform. Resolved role math is the contrast evidence, not screenshot pixels. Keep the distinction explicit.

colorSchemeContrast is read-only. Intended increased-contrast swatch math is separate evidence; actual system preference switching/redraw remains manual unless genuinely exercised. Never label ordinary screenshots as system high-contrast tests, or construct NSAppearance accessibility names as actual appearances.

The harness validates the four remaining pages and actual request NSTableView row counts/owned scrolling. These prove native geometry and programmatic scrolling only. Inspect light/dark PNGs at950/1120 and sparse/many/empty/unknown/error/recovery states. Preserve menu B fitting width288.

## Checks and boundaries

Compile optimized App for macOS14 and run shared formatter/Core/Store/menu checks appropriate to the change. Shared role API changes must also compile the historical MenuDesignPrototype harness; adapt types without redesigning it. Source subset scripts must include Appearance.swift. Use isolated output and UUID test identities; no user App quit/replacement. Keep T01–T11/Core/lifecycle untouched for visual work; Store scope is only the preference.


## Local price management (R20)

Settings opens PriceManagementContent as an in-window subpage, preserving the four main sections. Add/edit use the actual PriceEditor native sheet and explicit palette environment. Add is a menu Picker from Store all-history candidates only, never arbitrary model text. Editing keeps the model read-only. All three USD/million fields are required; invalid input preserves drafts and explicit errors. No global tint, new table columns or horizontal scroll.

Rows distinguish builtIn/custom and show per-row provenance. Used rows cannot be deleted regardless of source; visible explanation is required, not tooltip alone. Unknown scan/config state cannot imply a genuine empty candidate list. Saved table/revision and derived result provenance must agree; configuration errors remain visible while Token statistics continue.

Run Scripts/render-price-management.sh to render production views with isolated logs/defaults/price URL; assert document<=clip at950/1120 in both palettes/light-dark and startup legacy scrollbars. It also checks actual NSTextField bindings and persisted no-rescan edits. Plain form root renders are not native sheet interaction proof; if offscreen AX cannot press production buttons, record that limitation. Full UI harness must inject price URLs even when not testing pricing.

## Overview refinement (R21/T15)

Read [overview contract](../../../docs/dashboard-model-filter-design.md). Only the overview gets the near-white overviewBackground role. Four independent white cards share row height and preserve unknown/partial hints. Exact model plus period filters all cards, trend and lower details; native dropdown shows current-range record counts, including zero. Long models must fit950pt; vertical scrolling remains allowed. Large USD values choose26/17pt by intrinsic single-line width, then wrap fully. Do not truncate money or hide unknown coverage. `Scripts/render-overview.sh` covers both palettes/schemes and startup legacy scrollers; seeded state/geometry is not pointer or VoiceOver proof.

The overview model Picker keeps All first; other historical/current-selection candidates sort by current-period pre-filter record counts descending, then exact model ID ascending for ties. Missing counts are zero. Reordering must retain selection and never change other page/menu ordering or scan logs.


## Overview trend modes (R23/T16)

Native270pt segmented Picker selects Token, accepted record count or API-equivalent USD; defaultToken, view-local state retained across model/period updates. It changes only the trend, does not scan/reprice or mutate the four cards. Use shared paired scalar summaries. Record counts are not confirmed request counts. Money shows Decimal reference subtotals and explicit partial/unavailable states, triangle=partial/diamond=unpriced with visible words/coverage. Unknown is not a zero-price bar. Dense>12buckets omit individual text annotations but retain pointAX; global legend/help stays visible. Per-point hover is not promised in dense mode.

Daily categorical axis uses about6 first/last-inclusive ticks. On the current native Charts host `AxisMarks(values:ticks)` alone still rendered all30 category labels: conditionally emit AxisValueLabel text only for included ticks as well. Document<=clip is necessary but does not catch label overlap: visually inspect dense30date, microUSD, zero-price and unavailablePNG. USDaxis uses3significant digits for distinct tiny ticks; two-decimal card '<$0.01' sentinel is unsuitable for tick labels. Offscreen seeded modes do not prove actual segmented-control mouse/keyboard/VoiceOver interaction.
