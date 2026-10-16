import AppKit
import SwiftUI

@main struct PriceManagementVerification {
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
        let root = fm.temporaryDirectory.appendingPathComponent("price-ui-" + UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try fm.createDirectory(at: output, withIntermediateDirectories: true)
        let palette = AppPalette(rawValue: CommandLine.arguments[2])!
        let legacy = CommandLine.arguments.contains("--legacy")
        if legacy { precondition(NSScroller.preferredScrollerStyle == .legacy) }
        let longModel = "example-model-with-a-very-long-exact-name-and-no-guessed-alias"
        let observed = ["gpt-6.1-sol", "older-unpriced-model", longModel, "Unknown model"]
        for (i, model) in observed.enumerated() {
            let timestamp = "2025-01-01T12:00:00Z"
            let text = "{\"type\":\"session_meta\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"id\":\"s\(i)\",\"cwd\":\"/synthetic\"}}\n"
                + "{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"s\(i)\",\"response_id\":\"r-\(i)\",\"model\":\"\(model)\",\"usage\":{\"input_tokens\":1000,\"cached_input_tokens\":800,\"output_tokens\":100,\"reasoning_output_tokens\":0}}}\n"
            try Data(text.utf8).write(to: sessions.appendingPathComponent("s\(i).jsonl"))
        }
        let file = root.appendingPathComponent("config/prices.json")
        let custom = try ModelPrice(model: longModel, input: "2.123456789", cachedInput: "0.0000001", output: "10")
        let unused = try ModelPrice(model: "unused-custom-model", input: "0", cachedInput: "0", output: "0")
        let oldSnapshot = try PriceCatalog.builtIn.removing("gpt-5.6-sol").removing("gpt-6-sol")
        try PriceCatalogFile(url: file).save(oldSnapshot.setting(custom).setting(unused))
        let suite = "price-ui-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        defaults.set(palette.rawValue, forKey: "CodexStatsColorPalette")
        let store = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(store)
        precondition(store.priceCandidates == ["older-unpriced-model"])
        precondition(store.deletePriceBlockReason("gpt-6.1-sol") != nil)
        precondition(store.deletePriceBlockReason(longModel) != nil)
        precondition(store.deletePriceBlockReason("unused-custom-model") == nil)
        for (name, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
            for width in [950.0, 1120.0] {
                try await capture(DashboardView(initialSection: .settings, initialPriceManagement: true).environmentObject(store),
                    size: NSSize(width: width, height: width == 950 ? 630 : 760), scheme: scheme, palette: palette,
                    path: output.appendingPathComponent("prices-\(Int(width))-\(name).png"), verifyScroll: true)
            }
            try await capture(PriceEditor(entry: nil).environmentObject(store), size: NSSize(width: 488, height: 400), scheme: scheme, palette: palette,
                path: output.appendingPathComponent("add-price-\(name).png"))
            try await capture(PriceEditor(entry: custom).environmentObject(store), size: NSSize(width: 488, height: 420), scheme: scheme, palette: palette,
                path: output.appendingPathComponent("edit-price-\(name).png"), editFields: true)
        }
        let success = store.lastSuccessfulRefresh
        precondition(store.newBuiltInPrices.map(\.model) == ["gpt-5.6-sol", "gpt-6-sol"])
        let imported = await store.addNewBuiltInPrices()
        precondition(imported && store.newBuiltInPrices.isEmpty && store.lastSuccessfulRefresh == success)
        try await capture(DashboardView(initialSection: .settings, initialPriceManagement: true).environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("import-complete-950-light.png"), verifyScroll: true)
        let saved = await store.savePrice(model: "older-unpriced-model", input: "3", cachedInput: "0.2", output: "11", adding: true)
        precondition(saved && store.lastSuccessfulRefresh == success && store.priceCandidates.isEmpty)
        try await capture(DashboardView(initialSection: .settings, initialPriceManagement: true).environmentObject(store),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("no-candidates-950-light.png"), verifyScroll: true)
        try fm.removeItem(at: file)
        try fm.createDirectory(at: file, withIntermediateDirectories: true)
        let broken = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(broken)
        precondition(broken.hasReport && broken.priceError != nil && broken.catalog == nil)
        try await capture(DashboardView(initialSection: .settings, initialPriceManagement: true).environmentObject(broken),
            size: NSSize(width: 950, height: 630), scheme: .light, palette: palette,
            path: output.appendingPathComponent("unavailable-950-light.png"), verifyScroll: true)
        print("PASS: production price page/add-edit form, all-history exact candidate filtering, built-in/custom protection, persisted add and no rescan; palette=\(palette.rawValue), legacy=\(legacy). Native text edits/geometry/static renders only; no actual pointer, dropdown selection, VoiceOver or production App operation.")
    }
    @MainActor static func finish(_ store: UsageStore) async {
        let deadline = Date().addingTimeInterval(10)
        while store.loading { precondition(Date() < deadline); try? await Task.sleep(nanoseconds: 5_000_000) }
    }
    @MainActor static func descendants<T: NSView>(_ view: NSView, of type: T.Type) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants($0, of: type) }
    }
    @MainActor static func findAccessibility(_ value: Any, identifier: String, depth: Int = 0) -> (any NSAccessibilityProtocol)? {
        guard depth < 20, let element = value as? any NSAccessibilityProtocol else { return nil }
        if element.accessibilityIdentifier() == identifier { return element }
        for child in element.accessibilityChildren() ?? [] {
            if let found = findAccessibility(child, identifier: identifier, depth: depth + 1) { return found }
        }
        return nil
    }
    @MainActor static func verifySheet(in view: NSView, owner: NSWindow, output: URL) async throws {
        var evidence: [String] = []
        for identifier in ["add-model-price", "edit-price-example-model-with-a-very-long-exact-name-and-no-guessed-alias"] {
            if let action = findAccessibility(view, identifier: identifier), action.accessibilityPerformPress() {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard let sheet = NSApp.windows.first(where: { $0.isSheet && $0.sheetParent === owner }), let content = sheet.contentView else {
                    throw NSError(domain: "PriceUI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Production price action did not present its native sheet"])
                }
                sheet.appearance = owner.appearance
                try await Task.sleep(nanoseconds: 80_000_000)
                content.layoutSubtreeIfNeeded()
                guard let image = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw NSError(domain: "PriceUI", code: 3) }
                content.cacheDisplay(in: content.bounds, to: image)
                let suffix = identifier.hasPrefix("add") ? "add" : "edit"
                try image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("actual-sheet-" + suffix + ".png"))
                evidence.append("PASS: production " + suffix + " action via own accessibility element; native isSheet=true and sheetParent===ownWindow; size=\(content.bounds.size)")
                // AppKit test-host cleanup is not proof of production Cancel/Escape behavior.
                owner.endSheet(sheet); sheet.orderOut(nil)
                try await Task.sleep(nanoseconds: 80_000_000)
            } else {
                evidence.append("UNVERIFIED: own offscreen accessibility action unavailable: " + identifier + "; standalone production form rendered separately")
            }
        }
        try (evidence.joined(separator: "\n") + "\n").write(to: output.appendingPathComponent("native-sheet-actions.txt"), atomically: true, encoding: .utf8)
        evidence.forEach { print($0) }
    }
    @MainActor static func capture<V: View>(_ root: V, size: NSSize, scheme: ColorScheme, palette: AppPalette, path: URL,
                                          verifyScroll: Bool = false, editFields: Bool = false) async throws {
        let controller = NSHostingController(rootView: root.environment(\.appPalette, palette).environment(\.colorScheme, scheme))
        let view = controller.view
        let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: -3000, y: -3000), size: size), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentViewController = controller; window.setContentSize(size); window.orderBack(nil)
        try await Task.sleep(nanoseconds: 350_000_000)
        view.layoutSubtreeIfNeeded()
        if verifyScroll {
            let scrolls = descendants(view, of: NSScrollView.self).filter { $0.documentView != nil }
            precondition(scrolls.count == 1)
            let scroll = scrolls[0], document = scroll.documentView!
            precondition(document.bounds.width <= scroll.contentView.bounds.width + 1, "Price page horizontal overflow")
            let evidence = "host=\(view.bounds.size); document=\(document.bounds.size); clip=\(scroll.contentView.bounds.size); legacy=\(scroll.scrollerStyle == .legacy)"
            try evidence.write(to: path.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
            print("PRICE GEOMETRY " + evidence)
        }
        if editFields {
            let fields = descendants(view, of: NSTextField.self).filter { $0.isEditable }
            precondition(fields.count == 3, "Three production price text fields")
            let before = fields.map(\.stringValue)
            fields[0].stringValue = "0.00000001"
            NotificationCenter.default.post(name: NSControl.textDidChangeNotification, object: fields[0])
            fields[0].sendAction(fields[0].action, to: fields[0].target)
            try await Task.sleep(nanoseconds: 80_000_000)
            view.layoutSubtreeIfNeeded()
            precondition(descendants(view, of: NSTextField.self).contains { $0.isEditable && $0.stringValue == "0.00000001" })
            print("FORM native editable fields=\(before); entered exact micro-price via real NSTextField binding")
        }
        if verifyScroll && path.lastPathComponent == "prices-950-light.png" {
            try await verifySheet(in: view, owner: window, output: path.deletingLastPathComponent())
        }
        guard let image = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "PriceUI", code: 1) }
        view.cacheDisplay(in: view.bounds, to: image)
        try image.representation(using: .png, properties: [:])!.write(to: path)
        window.orderOut(nil); window.contentViewController = nil; window.close()
    }
}
