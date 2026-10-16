import AppKit
import SwiftUI

@main struct OverviewVerification {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await run(); app.terminate(nil) }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
        }
        app.run()
    }
    @MainActor static func run() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("overview-ui-" + UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        let palette = AppPalette(rawValue: CommandLine.arguments[2])!
        let legacy = CommandLine.arguments.contains("--legacy")
        if legacy { precondition(NSScroller.preferredScrollerStyle == .legacy) }
        let long = "example-model-with-a-very-long-exact-name-and-no-guessed-alias"
        let models = ["gpt-5.6-sol", "gpt-6-sol", "codex-auto-review", long, "unknown-cache-model", "old-model"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let today = calendar.startOfDay(for: Date())
        for (i, model) in models.enumerated() {
            let day = i == 5 ? today.addingTimeInterval(-60 * 86400) : today
            var text = "{\"type\":\"session_meta\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: day))\",\"payload\":{\"id\":\"s\(i)\",\"cwd\":\"/synthetic\"}}\n"
            for j in 0..<8 {
                let timestamp = ISO8601DateFormatter().string(from: day.addingTimeInterval(Double(8 + j) * 3600))
                let cache = i == 4 ? "" : ",\"cached_input_tokens\":90000000"
                text += "{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"s\(i)\",\"response_id\":\"r-\(i)-\(j)\",\"model\":\"\(model)\",\"usage\":{\"input_tokens\":100000000\(cache),\"output_tokens\":1000000,\"reasoning_output_tokens\":500000}}}\n"
            }
            try Data(text.utf8).write(to: sessions.appendingPathComponent("s\(i).jsonl"))
        }
        let file = root.appendingPathComponent("prices.json")
        let suite = "overview-ui-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        defaults.set(palette.rawValue, forKey: "CodexStatsColorPalette")
        let store = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(store)
        precondition(store.report.records(in: .today).count == 40)
        let checked = store.overviewSummary(in: .today).data
        let hourlyTotal = checked.hourlyTotals.reduce(TokenUsage()) { $0 + $1.usage }
        precondition(checked.usage.total == 4_040_000_000 && hourlyTotal == checked.usage)
        print("OVERVIEW ORACLE tokens=\(checked.usage.total) hourlySum=\(hourlyTotal.total) compact=\(abbreviated(checked.usage.total)) records=\(checked.recordCount)")
        precondition(checked.dailyRecordCounts.values.reduce(0, +) == 40 && checked.hourlyRecordCounts.values.reduce(0, +) == 40)
        let valuation = store.overviewSummary(in: .today).valuation
        precondition(valuation.hourly.count == 8 && valuation.hourly.values.allSatisfy { $0.state == .partial })
        let success = store.lastSuccessfulRefresh
        let base = store.summary
        let scenarios = [("all-partial", ""), ("priced", "gpt-6-sol"), ("unpriced", "codex-auto-review"),
                         ("long-name", long), ("unknown-cache", "unknown-cache-model"), ("zero", "old-model")]
        for (name, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
            for width in [950.0, 1120.0] {
                for (scenario, model) in scenarios {
                  for metric in OverviewTrendMetric.allCases {
                    try await capture(DashboardView(initialOverviewModel: model, initialTrendMetric: metric).environmentObject(store),
                        size: NSSize(width: width, height: width == 950 ? 630 : 760), scheme: scheme, palette: palette,
                        path: output.appendingPathComponent("overview-\(scenario)-\(metric.id)-\(Int(width))-\(name).png"), legacy: legacy)
                  }
                }
            }
        }
        precondition(store.summary === base && store.lastSuccessfulRefresh == success && !store.loading)
        try await capture(RequestsContent(period: .today, initialModel: "gpt-6-sol").environmentObject(store),
            size: NSSize(width: 765, height: 500), scheme: .light, palette: palette,
            path: output.appendingPathComponent("requests-initial-model.png"), legacy: legacy, requestRows: 8)
        let largePriceSaved = await store.savePrice(model: "gpt-6-sol", input: "1000000", cachedInput: "1", output: "10", adding: false)
        precondition(largePriceSaved && store.lastSuccessfulRefresh == success)
        try await capture(DashboardView(initialOverviewModel: "gpt-6-sol").environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("large-money-950-light.png"), legacy: legacy)
        precondition(trendDollarAxis(0.00001) == "$0.00001" && trendDollarAxis(0.00002) == "$0.00002")
        precondition(trendDollarAxis(0) == "$0")
        let freeSaved = await store.savePrice(model: "gpt-6-sol", input: "0", cachedInput: "0", output: "0", adding: false)
        precondition(freeSaved && store.overviewSummary(model: "gpt-6-sol", in: .today).valuation.total.state == .complete)
        try await capture(DashboardView(initialOverviewModel: "gpt-6-sol", initialTrendMetric: .cost).environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("zero-price-cost.png"), legacy: legacy)
        let microSaved = await store.savePrice(model: "gpt-6-sol", input: "0.00000001", cachedInput: "0", output: "0", adding: false)
        precondition(microSaved)
        try await capture(DashboardView(initialOverviewModel: "gpt-6-sol", initialTrendMetric: .cost).environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("micro-price-cost.png"), legacy: legacy)
        // 35 real accepted dates exercise the last30-date axis, partial + fully-unpriced buckets.
        var dense = "{\"type\":\"session_meta\",\"payload\":{\"id\":\"dense\",\"cwd\":\"/synthetic\"}}\n"
        for i in 1...35 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!.addingTimeInterval(12 * 3600)
            let timestamp = ISO8601DateFormatter().string(from: date)
            let dailyModels = i.isMultiple(of: 2) ? ["gpt-5.6-sol", "codex-auto-review"] : ["codex-auto-review"]
            for model in dailyModels {
                dense += "{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"dense\",\"response_id\":\"dense-\(i)-\(model)\",\"model\":\"\(model)\",\"usage\":{\"input_tokens\":100,\"cached_input_tokens\":50,\"output_tokens\":10}}}\n"
            }
        }
        try Data(dense.utf8).write(to: sessions.appendingPathComponent("dense.jsonl"))
        store.refresh(); await finish(store)
        store.period = .all
        precondition(store.overviewSummary(in: .all).data.dailyRecordCounts.count == 37)
        for metric in OverviewTrendMetric.allCases {
            try await capture(DashboardView(initialTrendMetric: metric).environmentObject(store),
                size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
                path: output.appendingPathComponent("dense-30dates-\(metric.id).png"), legacy: legacy)
        }
        store.period = .today
        let retainedSuccess = store.lastSuccessfulRefresh
        // Retained failure still renders accepted filtered data and a visible global error.
        try fm.removeItem(at: root)
        store.refresh(); await finish(store)
        precondition(store.hasReport && store.errorMessage != nil && store.lastSuccessfulRefresh == retainedSuccess)
        try await capture(DashboardView(initialOverviewModel: "gpt-6-sol").environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("retained-error-950-light.png"), legacy: legacy)
        print("PASS: production overview all/selected/long/unpriced/cache-incomplete/empty/retained-error at950/1120 light/dark; palette=\(palette.rawValue), startupLegacy=\(legacy); request initial model filters8 real native rows. Static geometry/programmatic data evidence only; pointer Picker selection, navigation click and VoiceOver remain unverified.")
    }
    @MainActor static func finish(_ store: UsageStore) async {
        let deadline = Date().addingTimeInterval(15)
        while store.loading { precondition(Date() < deadline); try? await Task.sleep(nanoseconds: 5_000_000) }
    }
    @MainActor static func descendants<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
    }
    @MainActor static func capture<V: View>(_ root: V, size: NSSize, scheme: ColorScheme, palette: AppPalette, path: URL,
                                          legacy: Bool, requestRows: Int? = nil) async throws {
        let controller = NSHostingController(rootView: root.environment(\.appPalette, palette).environment(\.colorScheme, scheme))
        let view = controller.view
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: -3000), size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = controller; window.setContentSize(size); window.orderBack(nil)
        try await Task.sleep(nanoseconds: 150_000_000)
        view.layoutSubtreeIfNeeded()
        precondition(abs(view.bounds.width - size.width) < 1, "Root must fit requested width")
        let scrolls = descendants(view, of: NSScrollView.self).filter { $0.documentView != nil }
        precondition(!scrolls.isEmpty, "Production scroll must exist")
        var evidence: [String] = []
        for scroll in scrolls {
            let document = scroll.documentView!
            precondition(document.bounds.width <= scroll.contentView.bounds.width + 1, "Horizontal overflow")
            if legacy { precondition(scroll.scrollerStyle == .legacy) }
            evidence.append("host=\(view.bounds.size); document=\(document.bounds.size); clip=\(scroll.contentView.bounds.size); legacy=\(scroll.scrollerStyle == .legacy)")
        }
        if let requestRows {
            precondition(descendants(view, of: NSTableView.self).first?.numberOfRows == requestRows)
        }
        try evidence.joined(separator: "\n").write(to: path.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        print("OVERVIEW GEOMETRY \(path.lastPathComponent) " + evidence.joined(separator: "; "))
        guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "OverviewUI", code: 1) }
        view.cacheDisplay(in: view.bounds, to: image)
        try image.representation(using: .png, properties: [:])!.write(to: path)
        window.orderOut(nil); window.contentViewController = nil; window.close()
    }
}
