import AppKit
import SwiftUI

@main
struct UIPreview {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = "codex-stats-preview-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(ProcessInfo.processInfo.environment["CODEX_HOME"], forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        defaults.set(ProcessInfo.processInfo.environment["CODEX_STATS_PREVIEW_PALETTE"] ?? "cyan", forKey: "CodexStatsColorPalette")
        let priceFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-prices-" + UUID().uuidString).appendingPathComponent("prices.json")
        let store = UsageStore(defaults: defaults, priceFileURL: priceFileURL)
        Task { @MainActor in
            do {
                for _ in 0..<100 {
                    if store.didScan && !store.loading { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                guard store.didScan, store.errorMessage == nil, !store.report.sessions.isEmpty else {
                    throw NSError(domain: "UIPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic logs did not load"])
                }
                if !CommandLine.arguments.contains("--valuation-only") {
                    let timed = store.report.records(in: .today).first { $0.requestID == "timed-last" }
                    guard timed?.requestEstimate?.durationMilliseconds == 45_000,
                          let speed = timed?.requestEstimate?.outputTokensPerSecond,
                          abs(speed - 2400.0 / 45.0) < 0.000001,
                          store.report.records(in: .today).first(where: { $0.requestID == "unknown-timing" })?.requestEstimate == nil else {
                        throw NSError(domain: "UIPreview", code: 7, userInfo: [NSLocalizedDescriptionKey: "Known/unknown estimate regression"])
                    }
                }
                let output = URL(fileURLWithPath: CommandLine.arguments[1])
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                if CommandLine.arguments.contains("--valuation-only") {
                    try await captureValuationStates(store: store, output: output)
                    defaults.removePersistentDomain(forName: suite)
                    app.terminate(nil)
                    return
                }
                try verifyTheme(output: output)
                try await verifyPaletteSwitch(store: store, output: output)
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    let loadingStore = UsageStore(defaults: defaults, priceFileURL: priceFileURL)
                    guard loadingStore.loading, !loadingStore.hasReport else { throw NSError(domain: "UIPreview", code: 9) }
                    try await capture(MenuPanelView().environmentObject(loadingStore).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-loading-\(name).png"), scheme: scheme,
                        fitContentHeight: true, settle: false)
                    guard loadingStore.loading, !loadingStore.hasReport else { throw NSError(domain: "UIPreview", code: 9) }
                    try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 1120, height: 760), path: output.appendingPathComponent("overview-\(name).png"), scheme: scheme)
                    store.period = .sevenDays
                    try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 1120, height: 760), path: output.appendingPathComponent("overview-7days-\(name).png"), scheme: scheme)
                    store.period = .today
                    try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-\(name).png"), scheme: scheme, fitContentHeight: true)
                    for (suffix, period) in [("7days", UsagePeriod.sevenDays), ("30days", .thirtyDays), ("all", .all)] {
                        store.period = period
                        try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-\(suffix)-\(name).png"), scheme: scheme, fitContentHeight: true)
                    }
                    store.period = .today
                    for width in [1120.0, 950.0] {
                        try await capture(DashboardView(initialSection: .requests).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: width == 950 ? 630 : 760), path: output.appendingPathComponent("requests-\(Int(width))-\(name).png"), scheme: scheme)
                        guard let request = store.report.records(in: .today).first(where: { $0.requestID == "timed-last" }) else {
                            throw NSError(domain: "UIPreview", code: 4)
                        }
                        try await capture(DashboardView(initialSection: .requests, initialRequestSelection: request.id).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: width == 950 ? 630 : 760), path: output.appendingPathComponent("inspector-\(Int(width))-\(name).png"), scheme: scheme)
                    }
                    for width in [1050.0, 1116.0, 1117.0, 1118.0, 1280.0] {
                        try await capture(DashboardView(initialSection: .requests).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: 760), path: output.appendingPathComponent("requests-resize-\(Int(width))-\(name).png"), scheme: scheme)
                    }
                    for (suffix, id) in [("known", "timed-last"), ("unknown", "unknown-timing")] {
                        let request = store.report.records(in: .today).first { $0.requestID == id }!
                        try await capture(RequestDetailView(record: request).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: 360, height: 700), path: output.appendingPathComponent("request-detail-\(suffix)-\(name).png"), scheme: scheme)
                    }
                    try await capture(DiagnosticSummary(diagnostics: store.report.diagnostics, initiallyExpanded: true).padding(20).frame(width: 700, height: 350, alignment: .topLeading).background(CPTheme.viewBackground).environment(\.colorScheme, scheme),
                        size: NSSize(width: 700, height: 350), path: output.appendingPathComponent("diagnostics-\(name).png"), scheme: scheme)
                    try await capture(PendingUsageView(loading: true, error: nil).frame(width: 700, height: 400).background(CPTheme.viewBackground).environment(\.colorScheme, scheme),
                        size: NSSize(width: 700, height: 400), path: output.appendingPathComponent("first-load-\(name).png"), scheme: scheme)
                }
                try await captureRequestScrollStates(store: store, output: output)
                try await captureStatusStates(store: store, output: output)
                try await captureValuationStates(store: store, output: output)
                let originalRoot = store.rootPath
                let menuFixtureRoot = FileManager.default.temporaryDirectory.appendingPathComponent("codexstats-menu-state-" + UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: menuFixtureRoot) }
                let fixtureSessions = menuFixtureRoot.appendingPathComponent("sessions")
                try FileManager.default.createDirectory(at: fixtureSessions, withIntermediateDirectories: true)
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let lines: [[String: Any]] = [
                    ["type": "session_meta", "timestamp": timestamp, "payload": ["id": "menu-unknown-model", "cwd": "/example/menu-state"]],
                    ["type": "event_msg", "timestamp": timestamp, "payload": ["type": "token_count", "info": ["total_token_usage":
                        ["input_tokens": 1_234_567_890, "cached_input_tokens": 1_200_000_000, "output_tokens": 6_789, "reasoning_output_tokens": 5_000]]]]
                ]
                let fixture = try lines.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }.joined(separator: "\n") + "\n"
                try fixture.write(to: fixtureSessions.appendingPathComponent("unknown.jsonl"), atomically: true, encoding: .utf8)
                store.updateRoot(menuFixtureRoot.path)
                while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                guard store.hasReport, store.errorMessage == nil, store.summary.usage.cachedInputKnown,
                      store.summary.usage.reasoningKnown, store.summary.models.first?.model == "Unknown model" else {
                    throw NSError(domain: "UIPreview", code: 10)
                }
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-unknown-model-known-fields-\(name).png"), scheme: scheme, fitContentHeight: true)
                }
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    store.updateRoot(originalRoot + "/empty")
                    while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                    guard store.hasReport, store.errorMessage == nil else { throw NSError(domain: "UIPreview", code: 5) }
                    try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 1120, height: 760), path: output.appendingPathComponent("empty-\(name).png"), scheme: scheme)
                    try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-empty-\(name).png"), scheme: scheme, fitContentHeight: true)
                    store.updateRoot(originalRoot + "/absent")
                    while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                    guard !store.hasReport, store.errorMessage != nil else { throw NSError(domain: "UIPreview", code: 6) }
                    try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 1120, height: 760), path: output.appendingPathComponent("error-\(name).png"), scheme: scheme)
                    try await capture(DashboardView(initialSection: .settings).environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 950, height: 630), path: output.appendingPathComponent("error-settings-\(name).png"), scheme: scheme)
                    try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-error-\(name).png"), scheme: scheme, fitContentHeight: true)
                }
                try FileManager.default.removeItem(at: menuFixtureRoot)
                print("PASS: native light/dark overview, four-range/loading/unknown-model/fitting-width menu, requests/inspector at 1120 and 950, known/unknown timing, grouped diagnostics, pending/real empty/error fixtures; all pages at 950x630 with warnings, retained-data failure, info-only recovery and status-sheet content; resolved light/dark palette contrast, four remaining dashboard pages and 80-record native request scrolling. Actual system high contrast remains unverified.")
                fflush(stdout)
                defaults.removePersistentDomain(forName: suite)
                app.terminate(nil)
            } catch {
                defaults.removePersistentDomain(forName: suite)
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    @MainActor static func verifyTheme(output: URL) throws {
        // Resolve the same production roles from explicit SwiftUI environments.
        // This checks palette/scheme changes without a global theme or cached Color.
        let colors: [String: CPTheme] = ["accent": .accent, "input": .cyan, "output": .purple,
            "risk": .orange, "page": .viewBackground, "section": .sectionBackground,
            "card": .cardBackground, "selection": .selection, "header": .headerBackground,
            "overview": .overviewBackground, "metric": .metricBackground, "chart": .chart, "action": .actionFill, "stroke": .stroke]
        let appearances: [(AppPalette, ColorScheme, [String: UInt32])] = [
            (.cyan, .light, ["accent": 0x23747F, "input": 0x286F96, "output": 0x735DAA,
                "risk": 0x975813, "overview": 0xF8FBFC, "page": 0xF3FAFA, "section": 0xEAF5F5, "card": 0xFFFFFF,
                "header": 0xFCFEFE, "metric": 0xEDF7F8, "chart": 0x8BC7CE,
                "selection": 0xDFF0F2, "action": 0x23747F, "stroke": 0xDFEBED]),
            (.cyan, .dark, ["accent": 0x6BC5D0, "input": 0x79B8E5, "output": 0xB4A3E4,
                "risk": 0xEEB370, "overview": 0x111E22, "page": 0x111E22, "section": 0x17282D, "card": 0x1C2C31,
                "header": 0x17282D, "metric": 0x20343B, "chart": 0x579CA6,
                "selection": 0x203F46, "action": 0x23747F, "stroke": 0x38535A]),
            (.blue, .light, ["accent": 0x3D62AD, "input": 0x286F96, "output": 0x735DAA,
                "risk": 0x975813, "overview": 0xF9FAFD, "page": 0xF5F7FB, "section": 0xEFF2F8, "card": 0xFFFFFF,
                "header": 0xFFFFFF, "metric": 0xFFFFFF, "chart": 0x83A5DF,
                "selection": 0xE6EDF9, "action": 0x3D62AD, "stroke": 0xE5E9F1]),
            (.blue, .dark, ["accent": 0x9EBEF3, "input": 0x79B8E5, "output": 0xB4A3E4,
                "risk": 0xEEB370, "overview": 0x141E2D, "page": 0x141E2D, "section": 0x1B293D, "card": 0x202F44,
                "header": 0x1B293D, "metric": 0x202F44, "chart": 0x7399CF,
                "selection": 0x293E5E, "action": 0x3D62AD, "stroke": 0x40536F])
        ]
        var evidence = ["Resolved sRGB dynamic roles and WCAG contrast; native semantic text remains system-managed."]
        for (palette, scheme, expectedValues) in appearances {
            let state = palette.rawValue + (scheme == .dark ? "-dark" : "-light")
            var environment = EnvironmentValues()
            environment.appPalette = palette
            environment.colorScheme = scheme
            let resolved = colors.mapValues { NSColor($0.resolve(in: environment)).usingColorSpace(.sRGB)! }
            for role in expectedValues.keys.sorted() {
                let color = resolved[role]!
                let hex = UInt32((color.redComponent * 255).rounded()) << 16
                    | UInt32((color.greenComponent * 255).rounded()) << 8
                    | UInt32((color.blueComponent * 255).rounded())
                let expected = expectedValues[role]!
                guard hex == expected, abs(color.alphaComponent - 1) < 0.000001 else {
                    throw NSError(domain: "UIPreview", code: 20,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected dynamic color \(state)/\(role): \(hex)"])
                }
                evidence.append(String(format: "%@ %@ #%06X", state, role, hex))
            }
            for foreground in ["accent", "input", "output", "risk"] {
                for background in ["overview", "page", "section", "card", "selection", "header", "metric"] {
                    let ratio = contrast(resolved[foreground]!, resolved[background]!)
                    guard ratio >= 4.5 else {
                        throw NSError(domain: "UIPreview", code: 21,
                            userInfo: [NSLocalizedDescriptionKey: "Low contrast \(state) \(foreground)/\(background): \(ratio)"])
                    }
                    evidence.append(String(format: "%@ %@/%@ %.3f:1", state, foreground, background, ratio))
                }
            }
            let actionContrast = contrast(NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), resolved["action"]!)
            guard actionContrast >= 4.5 else { throw NSError(domain: "UIPreview", code: 22) }
            evidence.append(String(format: "%@ white/action %.3f:1", state, actionContrast))
            // Banner fills are translucent, so check the resulting backdrop,
            // rather than assuming the opaque risk role is sufficient.
            for opacity in [0.04, 0.06, 0.07] {
                let risk = resolved["risk"]!, page = resolved["page"]!
                let fill = NSColor(srgbRed: risk.redComponent * opacity + page.redComponent * (1 - opacity),
                    green: risk.greenComponent * opacity + page.greenComponent * (1 - opacity),
                    blue: risk.blueComponent * opacity + page.blueComponent * (1 - opacity), alpha: 1)
                let ratio = contrast(risk, fill)
                guard ratio >= 4.5 else { throw NSError(domain: "UIPreview", code: 23) }
                evidence.append(String(format: "%@ risk/risk-fill-%.2f-over-page %.3f:1", state, opacity, ratio))
            }
            // colorSchemeContrast is read-only. Check intended swatches only;
            // actual system increased-contrast resolution remains unverified.
            let rgb: UInt32 = palette == .cyan
                ? (scheme == .dark ? 0x829CA3 : 0x71888D)
                : (scheme == .dark ? 0x91A3BD : 0x75839D)
            let intendedStroke = NSColor(srgbRed: Double((rgb >> 16) & 255) / 255,
                green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, alpha: 1)
            let hcChart = resolved["accent"]!
            for background in ["page", "section", "card"] {
                let ratio = contrast(intendedStroke, resolved[background]!)
                guard ratio >= 3, contrast(hcChart, resolved[background]!) >= 3 else { throw NSError(domain: "UIPreview", code: 23) }
                evidence.append(String(format: "%@ intended-high-contrast-swatch/%@ %.3f:1 (OS preference unverified)", state, background, ratio))
            }
        }
        evidence.append("UNVERIFIED: actual system increased-contrast appearance/resolution; no OS preference was changed.")
        try (evidence.joined(separator: "\n") + "\n").write(to: output.appendingPathComponent("theme-contrast.txt"), atomically: true, encoding: .utf8)
        print("PASS: cyan/blue light/dark environment roles, text/action/risk >=4.5:1; intended HC swatches >=3:1 (actual OS preference unverified)")
    }

    /// Programmatic native controls in one mounted host, never the user's App.
    @MainActor static func verifyPaletteSwitch(store: UsageStore, output: URL) async throws {
        let originalPalette = store.palette
        let originalPeriod = store.period
        defer { store.palette = originalPalette; store.period = originalPeriod }
        store.period = .today
        guard let record = store.report.records(in: .today).first(where: { $0.requestID == "timed-last" }) else {
            throw NSError(domain: "UIPreview", code: 30)
        }
        var evidence = ["Same mounted production Dashboard/Menu hosts; programmatic NSTextField edits and Store binding changes. No root replacement or user-App interaction."]
        func descendants<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
            (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
        }
        func bitmap(_ view: NSView, at path: URL) throws -> NSBitmapImageRep {
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "UIPreview", code: 31) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "UIPreview", code: 31) }
            try data.write(to: path)
            return bitmap
        }
        func checkPixel(_ bitmap: NSBitmapImageRep, view: NSView, role: CPTheme, palette: AppPalette, scheme: ColorScheme) throws {
            var environment = EnvironmentValues()
            environment.appPalette = palette
            environment.colorScheme = scheme
            let expected = NSColor(role.resolve(in: environment)).usingColorSpace(.sRGB)!
            let x = Int(3 * CGFloat(bitmap.pixelsWide) / view.bounds.width)
            let y = Int(200 * CGFloat(bitmap.pixelsHigh) / view.bounds.height)
            // cacheDisplay returns calibrated-RGB-tagged storage with the rendered
            // encoded RGB components. Compare those components, avoiding a second
            // calibrated→sRGB transform of the already rendered channels.
            let sampled = bitmap.colorAt(x: x, y: y)
            guard let actual = sampled,
                  abs(actual.redComponent - expected.redComponent) < 0.008,
                  abs(actual.greenComponent - expected.greenComponent) < 0.008,
                  abs(actual.blueComponent - expected.blueComponent) < 0.008 else {
                throw NSError(domain: "UIPreview", code: 32, userInfo: [NSLocalizedDescriptionKey: "Mounted host did not redraw \(palette.rawValue)/\(scheme)"])
            }
        }
        for (schemeName, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            for section in [DashboardSection.requests, .sessions, .settings] {
                store.palette = .cyan
                let controller = NSHostingController(rootView: DashboardView(initialSection: section, initialRequestSelection: record.id)
                    .environmentObject(store).environment(\.colorScheme, scheme))
                let host = controller.view
                let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 1120, height: 760),
                    styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentViewController = controller
                window.setContentSize(NSSize(width: 1120, height: 760))
                window.orderBack(nil)
                defer { window.close() }
                let menu = NSHostingView(rootView: MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme))
                let menuWindow = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 288, height: 420),
                    styleMask: [.titled], backing: .buffered, defer: false)
                menuWindow.isReleasedWhenClosed = false
                menuWindow.appearance = window.appearance
                menuWindow.contentView = menu
                menuWindow.orderBack(nil)
                defer { menuWindow.close() }
                try await Task.sleep(nanoseconds: 300_000_000)
                host.layoutSubtreeIfNeeded()
                if section == .requests { try await presentRequestDetail(in: host) }
                let fields = descendants(host, of: NSTextField.self).filter { $0.isEditable }
                guard let field = fields.first(where: { ($0.placeholderString ?? "").contains(section == .settings ? "日志目录" : "搜索") }) else {
                    throw NSError(domain: "UIPreview", code: 33, userInfo: [NSLocalizedDescriptionKey: "No native editable field for \(section.rawValue): \(fields.map { $0.placeholderString ?? "nil" })"])
                }
                let query: String
                switch section {
                case .requests: query = "timed-last"
                case .sessions: query = "timed-project"
                default: query = "/synthetic/unsaved-path-must-survive"
                }
                field.stringValue = query
                field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
                try await Task.sleep(nanoseconds: 200_000_000)
                host.layoutSubtreeIfNeeded()
                let initialRows = descendants(host, of: NSTableView.self).first?.numberOfRows
                let initialSelection = descendants(host, of: NSTableView.self).first?.selectedRowIndexes
                if section == .requests {
                    guard initialRows == 1 else { throw NSError(domain: "UIPreview", code: 34, userInfo: [NSLocalizedDescriptionKey: "Native search binding did not filter \(section.rawValue): \(String(describing: initialRows))"]) }
                }
                if section == .requests {
                    guard initialSelection?.count == 1, NSApp.windows.contains(where: { $0.isSheet && $0.sheetParent === window }) else { throw NSError(domain: "UIPreview", code: 35) }
                }
                let summary = store.summary
                let success = store.lastSuccessfulRefresh
                let root = store.rootPath
                for palette in [AppPalette.cyan, .blue, .cyan] {
                    store.palette = palette
                    try await Task.sleep(nanoseconds: 200_000_000)
                    host.layoutSubtreeIfNeeded()
                    let current = descendants(host, of: NSTextField.self).first { $0.isEditable && $0.placeholderString == field.placeholderString }
                    guard current?.stringValue == query, store.palette == palette,
                          store.period == .today, store.rootPath == root,
                          store.lastSuccessfulRefresh == success, !store.loading, store.summary === summary,
                          descendants(host, of: NSTableView.self).first?.numberOfRows == initialRows,
                          descendants(host, of: NSTableView.self).first?.selectedRowIndexes == initialSelection else {
                        throw NSError(domain: "UIPreview", code: 36, userInfo: [NSLocalizedDescriptionKey: "State changed on palette switch: \(section.rawValue)"])
                    }
                    if section == .requests {
                        guard NSApp.windows.contains(where: { $0.isSheet && $0.sheetParent === window }) else { throw NSError(domain: "UIPreview", code: 45) }
                    }
                    let suffix = "\(section.icon)-\(palette.rawValue)-\(schemeName)"
                    let image = try bitmap(host, at: output.appendingPathComponent("switch-\(suffix).png"))
                    try checkPixel(image, view: host, role: .sectionBackground, palette: palette, scheme: scheme)
                    let menuImage = try bitmap(menu, at: output.appendingPathComponent("switch-menu-\(suffix).png"))
                    try checkPixel(menuImage, view: menu, role: .viewBackground, palette: palette, scheme: scheme)
                    if section == .requests, let detail = NSApp.windows.first(where: { $0.isSheet && $0.sheetParent === window })?.contentView {
                        let detailImage = try bitmap(detail, at: output.appendingPathComponent("switch-detail-\(palette.rawValue)-\(schemeName).png"))
                        try checkPixel(detailImage, view: detail, role: .viewBackground, palette: palette, scheme: scheme)
                    }
                }
                if section == .requests, let sheet = NSApp.windows.first(where: { $0.isSheet && $0.sheetParent === window }) {
                    window.endSheet(sheet)
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                evidence.append("PASS \(schemeName)/\(section.rawValue): cyan→blue→cyan on same hosts, native field/search query retained, rows/selected request retained; palette changed through Store binding; dashboard and menu background pixels updated; summary identity/root/range/success/loading unchanged.")
            }
        }
        try (evidence.joined(separator: "\n") + "\n").write(to: output.appendingPathComponent("palette-switch.txt"), atomically: true, encoding: .utf8)
        print("PASS: same-host palette redraw and native search/selection/unsaved settings retention, no scan or summary invalidation")
    }

    static func contrast(_ first: NSColor, _ second: NSColor) -> Double {
        func luminance(_ color: NSColor) -> Double {
            let channels = [Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent)]
            let components = channels.map { value -> Double in
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @MainActor static func captureRequestScrollStates(store: UsageStore, output: URL) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("codexstats-request-preview-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let originalRoot = store.rootPath
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var lines = ["{\"type\":\"session_meta\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"id\":\"many-requests\",\"cwd\":\"/synthetic/many-requests\"}}"]
        for index in 0..<80 {
            lines.append("{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"many-requests\",\"response_id\":\"response-\(index)\",\"model\":\"synthetic-request-model\",\"usage\":{\"input_tokens\":\(1000 + index),\"output_tokens\":100,\"cached_input_tokens\":500,\"reasoning_output_tokens\":50}}}")
        }
        try (lines.joined(separator: "\n") + "\n").write(to: sessions.appendingPathComponent("many.jsonl"), atomically: true, encoding: .utf8)
        store.updateRoot(root.path)
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
        guard store.hasReport, store.errorMessage == nil, store.report.records(in: .today).count == 80 else {
            throw NSError(domain: "UIPreview", code: 24)
        }
        for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            for width in [1120.0, 950.0] {
                try await capture(DashboardView(initialSection: .requests).environmentObject(store).environment(\.colorScheme, scheme),
                    size: NSSize(width: width, height: width == 950 ? 630 : 760), path: output.appendingPathComponent("requests-many-\(Int(width))-\(name).png"),
                    scheme: scheme, expectedRequestRows: 80)
            }
        }
        for width in [950.0, 1116.0, 1117.0, 1118.0, 1120.0] {
            try await capture(DashboardView(initialSection: .requests).environmentObject(store).environment(\.colorScheme, .light),
                size: NSSize(width: width, height: width == 950 ? 630 : 760), path: output.appendingPathComponent("requests-legacy-\(Int(width))-light.png"),
                scheme: .light, expectedRequestRows: 80, legacyScrollers: true)
        }
        store.updateRoot(originalRoot)
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
    }

    @MainActor static func captureStatusStates(store: UsageStore, output: URL) async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("codexstats-status-preview-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let originalRoot = store.rootPath
        let originalPeriod = store.period
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let known = """
        {"type":"session_meta","timestamp":"\(timestamp)","payload":{"id":"status-preview","cwd":"/synthetic/status"}}
        {"type":"token_usage_record","timestamp":"\(timestamp)","payload":{"thread_id":"status-preview","response_id":"response","model":"synthetic-status-model","usage":{"input_tokens":100,"output_tokens":10,"cached_input_tokens":50,"reasoning_output_tokens":5}}}

        """
        let incomplete = known.replacingOccurrences(of: ",\"cached_input_tokens\":50,\"reasoning_output_tokens\":5", with: "")
        try Data(incomplete.utf8).write(to: sessions.appendingPathComponent("status.jsonl"))
        store.updateRoot(root.path)
        store.period = .all
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
        guard store.hasReport, store.scanStatus.warningCount > 0 else { throw NSError(domain: "UIPreview", code: 11) }
        let successful = store.lastSuccessfulRefresh
        for state in ["warning", "failed-refresh", "recovered-info"] {
            if state == "failed-refresh" {
                try fm.removeItem(at: root)
                store.refresh()
                while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                guard store.hasReport, store.errorMessage != nil, store.lastSuccessfulRefresh == successful,
                      store.report.totals(in: .all).total == 110 else { throw NSError(domain: "UIPreview", code: 12) }
            } else if state == "recovered-info" {
                try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
                try Data(known.utf8).write(to: sessions.appendingPathComponent("status.jsonl"))
                let archive = root.appendingPathComponent("archived_sessions")
                try fm.createDirectory(at: archive, withIntermediateDirectories: true)
                try Data(known.utf8).write(to: archive.appendingPathComponent("status-copy.jsonl"))
                store.refresh()
                while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
                guard store.errorMessage == nil, !store.scanStatus.requiresAttention,
                      store.scanStatus.informationCount > 0 else { throw NSError(domain: "UIPreview", code: 13) }
            }
            for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                for section in DashboardSection.allCases {
                    try await capture(DashboardView(initialSection: section).environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 950, height: 630), path: output.appendingPathComponent("status-\(state)-\(section.icon)-\(name).png"), scheme: scheme)
                }
                try await capture(ScanStatusDetails().environmentObject(store).background(CPTheme.viewBackground).environment(\.colorScheme, scheme),
                    size: NSSize(width: 640, height: 420), path: output.appendingPathComponent("status-sheet-\(state)-\(name).png"), scheme: scheme)
            }
        }
        store.updateRoot(originalRoot)
        store.period = originalPeriod
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
    }

    @MainActor static func captureValuationStates(store: UsageStore, output: URL) async throws {
        let originalRoot = store.rootPath, originalPeriod = store.period
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("codexstats-valuation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = root.appendingPathComponent("sessions")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let items: [(String, String, [String: Int])] = [
            ("known", "gpt-6.1-sol", ["input_tokens": 1000, "cached_input_tokens": 800, "output_tokens": 100]),
            ("missing", "gpt-6.1-sol", ["input_tokens": 100, "output_tokens": 10]),
            ("full", "gpt-6-astra", ["input_tokens": 1000, "cached_input_tokens": 800, "output_tokens": 100]),
            ("unknown", "Unknown model", ["input_tokens": 100, "cached_input_tokens": 0, "output_tokens": 0]),
            ("micro", "gpt-6-luna", ["input_tokens": 1, "cached_input_tokens": 0, "output_tokens": 0])
        ]
        var lines: [[String: Any]] = [["type": "session_meta", "timestamp": timestamp, "payload": ["id": "valuation", "cwd": "/example/valuation"]]]
        for (id, model, usage) in items {
            lines.append(["type": "token_usage_record", "timestamp": timestamp,
                "payload": ["thread_id": "valuation", "response_id": id, "model": model, "usage": usage]])
        }
        let data = try lines.map { String(decoding: try JSONSerialization.data(withJSONObject: $0), as: UTF8.self) }.joined(separator: "\n") + "\n"
        try data.write(to: sessions.appendingPathComponent("valuation.jsonl"), atomically: true, encoding: .utf8)
        store.updateRoot(root.path)
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
        let summary = store.summary(in: .all)
        guard store.hasReport, store.errorMessage == nil, summary.valuation.total.exactUSD == "0.0092801",
              summary.valuation.total.state == .partial, summary.valuation.total.estimatedTokens == 2201,
              summary.valuation.total.unestimatedTokens == 210,
              summary.valuation.models["gpt-6.1-sol"]?.state == .partial,
              summary.valuation.models["gpt-6-astra"]?.state == .complete,
              summary.valuation.models["Unknown model"]?.state == .unavailable else { throw NSError(domain: "UIPreview", code: 60) }
        store.period = .all
        for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            for width in [950.0, 1120.0] {
                try await capture(DashboardView().environmentObject(store).environment(\.colorScheme, scheme),
                    size: NSSize(width: width, height: width == 950 ? 630 : 760),
                    path: output.appendingPathComponent("valuation-overview-\(Int(width))-\(name).png"), scheme: scheme)
            }
            try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("valuation-menu-\(name).png"), scheme: scheme, fitContentHeight: true)
            for section in [DashboardSection.sessions, .settings] {
                try await capture(DashboardView(initialSection: section).environmentObject(store).environment(\.colorScheme, scheme),
                    size: NSSize(width: 950, height: 630), path: output.appendingPathComponent("valuation-\(section.icon)-950-\(name).png"), scheme: scheme)
            }
            for record in store.report.records(in: .all) where ["known", "missing", "micro", "unknown"].contains(record.requestID ?? "") {
                try await capture(RequestDetailView(record: record).environmentObject(store).environment(\.colorScheme, scheme),
                    size: NSSize(width: 420, height: 600), path: output.appendingPathComponent("valuation-request-\(record.requestID!)-\(name).png"), scheme: scheme)
            }
        }
        store.updateRoot(originalRoot); store.period = originalPeriod
        while store.loading { try await Task.sleep(nanoseconds: 10_000_000) }
        print("PASS: valuation native full/partial/unavailable/micro fixtures, weighted cache semantics, exact hand oracle, overview at two widths and schemes")
    }

    @MainActor static func presentRequestDetail(in host: NSView) async throws {
        func tables(_ view: NSView) -> [NSTableView] {
            (view as? NSTableView).map { [$0] } ?? view.subviews.flatMap { tables($0) }
        }
        guard let table = tables(host).first, let index = table.selectedRowIndexes.first else { throw NSError(domain: "UIPreview", code: 46) }
        table.deselectAll(nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        try await Task.sleep(nanoseconds: 500_000_000)
        // Synthetic windows override appearance while the actual OS may remain
        // light. NSPanel does not inherit that parent override automatically.
        if let window = host.window, let sheet = NSApp.windows.first(where: { $0.isSheet && $0.sheetParent === window }) {
            sheet.appearance = window.appearance
            try await Task.sleep(nanoseconds: 100_000_000)
            sheet.contentView?.layoutSubtreeIfNeeded()
        }
        host.layoutSubtreeIfNeeded()
    }

    @MainActor static func nativeScrolls(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { nativeScrolls(in: $0) }
    }

    @MainActor static func capture<V: View>(_ root: V, size: NSSize, path: URL, scheme: ColorScheme, fitContentHeight: Bool = false, settle: Bool = true,
                                          expectedRequestRows: Int? = nil, legacyScrollers: Bool = false) async throws {
        let previewPalette = AppPalette(rawValue: ProcessInfo.processInfo.environment["CODEX_STATS_PREVIEW_PALETTE"] ?? "cyan") ?? .cyan
        let controller = NSHostingController(rootView: root.environment(\.appPalette, previewPalette))
        let view = controller.view
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = controller
        window.setContentSize(size)
        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
        window.orderBack(nil)
        if settle { try await Task.sleep(nanoseconds: 500_000_000) }
        view.layoutSubtreeIfNeeded()
        if path.lastPathComponent.hasPrefix("inspector-") { try await presentRequestDetail(in: view) }
        func requestTables(in parent: NSView) -> [NSTableView] {
            (parent as? NSTableView).map { [$0] } ?? parent.subviews.flatMap { requestTables(in: $0) }
        }
        let nativeRequestTables = requestTables(in: view).filter { [7, 10].contains($0.tableColumns.count) }
        if path.lastPathComponent.hasPrefix("requests-") || path.lastPathComponent.hasPrefix("inspector-") || expectedRequestRows != nil {
            guard nativeRequestTables.count == 1 else { throw NSError(domain: "UIPreview", code: 47, userInfo: [NSLocalizedDescriptionKey: "Expected exactly one native request table: \(path.lastPathComponent)"]) }
        }
        if let table = nativeRequestTables.first {
            if legacyScrollers {
                guard let scroll = table.enclosingScrollView else { throw NSError(domain: "UIPreview", code: 48) }
                scroll.scrollerStyle = .legacy
                scroll.autohidesScrollers = false
                scroll.hasVerticalScroller = true
                view.layoutSubtreeIfNeeded()
                try await Task.sleep(nanoseconds: 100_000_000)
                view.layoutSubtreeIfNeeded()
            }
            guard let scroll = table.enclosingScrollView,
                  table.bounds.width <= scroll.contentView.bounds.width + 1,
                  table.tableColumns.count == (size.width >= 1117 ? 10 : 7),
                  table.rect(ofColumn: table.tableColumns.count - 1).maxX <= scroll.documentVisibleRect.maxX + 1 else {
                throw NSError(domain: "UIPreview", code: 40, userInfo: [NSLocalizedDescriptionKey: "Request columns must all fit without horizontal scrolling: \(path.lastPathComponent), document=\(table.bounds.width), clip=\(table.enclosingScrollView?.contentView.bounds.width ?? 0)"])
            }
            let rect = scroll.convert(scroll.bounds, to: view)
            let top = view.isFlipped ? rect.minY : view.bounds.height - rect.maxY
            let evidence = "\(path.lastPathComponent): host=\(view.bounds.size), tableTop=\(top), tableHeight=\(rect.height), document=\(table.bounds.width), clip=\(scroll.contentView.bounds.width), columns=\(table.tableColumns.map { $0.width }), rows=\(table.numberOfRows), visibleRows=\(table.rows(in: scroll.documentVisibleRect))"
            print("REQUEST GEOMETRY " + evidence)
            let metrics = path.deletingPathExtension().appendingPathExtension("txt")
            try (evidence + "\n").write(to: metrics, atomically: true, encoding: .utf8)
            if let expectedRows = expectedRequestRows {
                guard table.numberOfRows == expectedRows, table.bounds.height > scroll.contentView.bounds.height else { throw NSError(domain: "UIPreview", code: 41) }
                table.scrollRowToVisible(expectedRows - 1)
                view.layoutSubtreeIfNeeded()
                guard NSLocationInRange(expectedRows - 1, table.rows(in: scroll.documentVisibleRect)) else { throw NSError(domain: "UIPreview", code: 42) }
                table.scrollRowToVisible(0)
                view.layoutSubtreeIfNeeded()
                print("PASS request native scrolling: \(expectedRows) real records; last row reached and returned to first")
            }
        }
        if path.lastPathComponent.hasPrefix("inspector-") {
            guard let sheet = NSApp.windows.first(where: { $0.isSheet && $0.sheetParent === window }), let content = sheet.contentView else {
                throw NSError(domain: "UIPreview", code: 43, userInfo: [NSLocalizedDescriptionKey: "Request selection must present a real native sheet; requested=\(window), host=\(String(describing:view.window)), attached=\(String(describing:window.attachedSheet)); windows=\(NSApp.windows.map { "\($0.title):sheet=\($0.isSheet),visible=\($0.isVisible),parent=\(String(describing: $0.sheetParent))" })"])
            }
            content.layoutSubtreeIfNeeded()
            guard let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw NSError(domain: "UIPreview", code: 44) }
            content.cacheDisplay(in: content.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: path.deletingLastPathComponent().appendingPathComponent("detail-sheet-" + path.lastPathComponent))
            print("PASS actual attached request sheet \(content.bounds.size), parent table retains full width")
            window.endSheet(sheet)
            try await Task.sleep(nanoseconds: 100_000_000)
            print("Programmatic AppKit dismissal only; production close/Escape remain manual")
        }
        if fitContentHeight {
            let fitting = view.fittingSize
            guard abs(fitting.width - 288) < 1, fitting.height.isFinite, fitting.height > 0 else {
                throw NSError(domain: "UIPreview", code: 8, userInfo: [NSLocalizedDescriptionKey: "Menu must remain 288pt wide with a finite fitting height: \(fitting)"])
            }
            window.setContentSize(NSSize(width: size.width, height: ceil(fitting.height)))
            if settle { try await Task.sleep(nanoseconds: 100_000_000) }
            view.layoutSubtreeIfNeeded()
            print("Menu layout: \(path.lastPathComponent) \(view.bounds.size)")
        }
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw NSError(domain: "UIPreview", code: 2)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "UIPreview", code: 3)
        }
        try data.write(to: path)
        if path.lastPathComponent.hasPrefix("valuation-request-") {
            guard let scroll = nativeScrolls(in: view).first, let document = scroll.documentView,
                  document.bounds.width <= scroll.contentView.bounds.width + 1 else { throw NSError(domain: "UIPreview", code: 61) }
            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, document.bounds.height - scroll.contentView.bounds.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
            try await Task.sleep(nanoseconds: 100_000_000)
            view.layoutSubtreeIfNeeded()
            guard scroll.documentVisibleRect.maxY >= document.bounds.maxY - 1 else { throw NSError(domain: "UIPreview", code: 62) }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: path.deletingLastPathComponent().appendingPathComponent("end-" + path.lastPathComponent))
        }
        window.close()
    }
}
