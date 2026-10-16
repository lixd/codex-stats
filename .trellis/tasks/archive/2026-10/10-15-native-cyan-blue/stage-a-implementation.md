# Stage A implementation handoff

2026-10-15. Started only after parent's recorded `stage-d.md` PASS. D geometry remains fixed; two color choices only.

## Files changed in this stage by implementer

- Added `Sources/App/Appearance.swift`: fixed `AppPalette` cyan/blue and Chinese labels; `EnvironmentValues.appPalette` defaults cyan; `CPTheme: ShapeStyle` preserves existing role names and resolves to a concrete Color from local palette/colorScheme/colorSchemeContrast. No AppKit appearance singleton, UserDefaults reads, provider cache or timers. Increased contrast chart resolves to accent; stroke uses the approved increased-contrast swatch.
- `Components.swift`: removed old CPTheme dynamic NSColor provider; updated the small number of Color-specific or mixed-style expressions with CPTheme/AnyShapeStyle. Formatting/TokenDetails behavior unchanged.
- `UsageStore.swift`: one published `palette` preference backed by the injected defaults (`CodexStatsColorPalette` cyan/blue); initialization defaults missing/unknown to cyan. didSet only persists; no timer/refresh/cache/report changes.
- `DashboardView.swift`, `MenuPanelView.swift`: inject the observable palette on the existing root view tree; diagnostic sheet explicitly receives it. Menu metric helper takes CPTheme role. No new .id, reconstruction or global control tint.
- `SessionsContent.swift`: Settings adds native palette Picker plus system-appearance explanation. Existing prominent save action uses the resolved Color because macOS14 tint expects Color. The existing path draft stays in its same view state.
- `Scripts/test-token-display.sh`, `Scripts/test-usage-store.sh`: explicitly compile Appearance.swift alongside their production source subset. Other App builders already glob Sources/App.
- `Tests/UsageStore/main.swift`: actual isolated preference missing/unknown defaults, both stored values recovered through new Store instances/defaults objects, and actual cyan→blue→cyan changes. Loading/report publishers remain silent and summary object, successful time, path/range/auto-refresh/interval stay unchanged.

Parent owns `Tests/UIPreview/main.swift`; not modified by this implementer during stage A.

## Checks run

PASS: `xcrun swiftc -swift-version 5 -parse-as-library -typecheck -framework AppKit -framework SwiftUI -framework Charts Sources/Core/*.swift Sources/App/*.swift`.

PASS: `Scripts/test-usage-store.sh` (real scanner and isolated defaults, previous status/cache regressions included).

PASS: `Scripts/test-token-display.sh` (16 boundaries each en_US/zh_CN/fr_FR).

PASS: `git diff --check`.

No product App installation, launch/quit/replacement, real logs/defaults, commit or push. Parent performs native environment re-resolution/render/same-host interaction tests, contrast, final optimized build and metadata/docs closeout. These tests above do not by themselves prove native redraw/state retention, actual system high contrast, user mouse/VoiceOver behavior or long-term residency.
