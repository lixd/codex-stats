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
        let store = UsageStore(defaults: defaults)
        Task { @MainActor in
            do {
                for _ in 0..<100 {
                    if store.didScan && !store.loading { break }
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                guard store.didScan, store.errorMessage == nil, !store.report.sessions.isEmpty else {
                    throw NSError(domain: "UIPreview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic logs did not load"])
                }
                let timed = store.report.records(in: .today).first { $0.requestID == "timed-last" }
                guard timed?.requestEstimate?.durationMilliseconds == 45_000,
                      let speed = timed?.requestEstimate?.outputTokensPerSecond,
                      abs(speed - 2400.0 / 45.0) < 0.000001,
                      store.report.records(in: .today).first(where: { $0.requestID == "unknown-timing" })?.requestEstimate == nil else {
                    throw NSError(domain: "UIPreview", code: 7, userInfo: [NSLocalizedDescriptionKey: "Known/unknown estimate regression"])
                }
                let output = URL(fileURLWithPath: CommandLine.arguments[1])
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    let loadingStore = UsageStore(defaults: defaults)
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
                        try await capture(DashboardView(initialSection: .models).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: 760), path: output.appendingPathComponent("models-\(Int(width))-\(name).png"), scheme: scheme)
                        try await capture(DashboardView(initialSection: .requests).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: 760), path: output.appendingPathComponent("requests-\(Int(width))-\(name).png"), scheme: scheme)
                        guard let request = store.report.records(in: .today).first(where: { $0.requestID == "timed-last" }) else {
                            throw NSError(domain: "UIPreview", code: 4)
                        }
                        try await capture(DashboardView(initialSection: .requests, initialRequestSelection: request.id).environmentObject(store).environment(\.colorScheme, scheme),
                            size: NSSize(width: width, height: 760), path: output.appendingPathComponent("inspector-\(Int(width))-\(name).png"), scheme: scheme)
                    }
                    for (suffix, id) in [("known", "timed-last"), ("unknown", "unknown-timing")] {
                        let request = store.report.records(in: .today).first { $0.requestID == id }!
                        try await capture(RequestDetailView(record: request).environment(\.colorScheme, scheme),
                            size: NSSize(width: 360, height: 700), path: output.appendingPathComponent("request-detail-\(suffix)-\(name).png"), scheme: scheme)
                    }
                    try await capture(DiagnosticSummary(diagnostics: store.report.diagnostics, initiallyExpanded: true).padding(20).frame(width: 700, height: 350, alignment: .topLeading).background(CPTheme.viewBackground).environment(\.colorScheme, scheme),
                        size: NSSize(width: 700, height: 350), path: output.appendingPathComponent("diagnostics-\(name).png"), scheme: scheme)
                    try await capture(PendingUsageView(loading: true, error: nil).frame(width: 700, height: 400).background(CPTheme.viewBackground).environment(\.colorScheme, scheme),
                        size: NSSize(width: 700, height: 400), path: output.appendingPathComponent("first-load-\(name).png"), scheme: scheme)
                }
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
                    try await capture(MenuPanelView().environmentObject(store).environment(\.colorScheme, scheme),
                        size: NSSize(width: 288, height: 420), path: output.appendingPathComponent("menu-error-\(name).png"), scheme: scheme, fitContentHeight: true)
                }
                try FileManager.default.removeItem(at: menuFixtureRoot)
                print("PASS: native light/dark overview, four-range/loading/unknown-model/fitting-width menu, models/requests/inspector at 1120 and 950, known/unknown timing, grouped diagnostics, pending/real empty/error fixtures")
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

    @MainActor static func capture<V: View>(_ root: V, size: NSSize, path: URL, scheme: ColorScheme, fitContentHeight: Bool = false, settle: Bool = true) async throws {
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
        window.orderBack(nil)
        if settle { try await Task.sleep(nanoseconds: 500_000_000) }
        view.layoutSubtreeIfNeeded()
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
        window.close()
    }
}
