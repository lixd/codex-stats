import Foundation
import Combine

@main struct StoreVerification {
    @MainActor static func main() async throws {
        try await verifyOverview()
        try await verifyPrices()
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("codex-stats-store-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let data = """
        {"type":"session_meta","timestamp":"2026-10-14T00:00:00Z","payload":{"id":"synthetic-store","cwd":"/synthetic"}}
        {"type":"token_usage_record","timestamp":"2026-10-14T12:00:01.123Z","payload":{"thread_id":"synthetic-store","response_id":"r","model":"gpt-6.1-sol","usage":{"input_tokens":100,"output_tokens":10,"cached_input_tokens":90,"reasoning_output_tokens":5}}}

        """
        try Data(data.utf8).write(to: sessions.appendingPathComponent("store.jsonl"))
        let suite = "codex-stats-store-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        let store = UsageStore(defaults: defaults, priceFileURL: root.appendingPathComponent("prices.json"))
        precondition(store.palette == .cyan)
        precondition(store.loading && !store.didScan && !store.hasReport && store.lastSuccessfulRefresh == nil)
        precondition(store.scanStatus.summary == "正在读取本地日志…")
        await finish(store)
        precondition(store.didScan && store.hasReport && store.errorMessage == nil)
        precondition(!store.scanStatus.requiresAttention && store.scanStatus.warningCount == 0)
        precondition(store.report.totals(in: .all).total == 110)
        let now = ISO8601DateFormatter().date(from: "2026-10-14T12:30:00Z")!

        var pairedPublications = 0
        let pairObserver = store.$snapshot.dropFirst().sink { next in
            let nextCost = next.valuation.summary(in: .all).total
            precondition(next.report.totals(in: .all).total == nextCost.estimatedTokens + nextCost.unestimatedTokens)
            let currentCost = store.snapshot.valuation.summary(in: .all).total
            precondition(store.report.totals(in: .all).total == currentCost.estimatedTokens + currentCost.unestimatedTokens)
            // @Published sends before storage changes: a query here must be invalidated after assignment.
            _ = store.summary(in: .all, now: now)
            pairedPublications += 1
        }
        let summary = store.summary(in: .today, now: now)
        precondition(summary.usage.total == 110 && summary.models.count == 1)
        precondition(summary.valuation.total.exactUSD == "0.000129")
        precondition(summary.valuation.total.estimatedTokens == 110 && summary.valuation.total.state == .complete)
        precondition(summary.valuation.sessions["synthetic-store"] == summary.valuation.total)
        precondition(summary.valuation.models["gpt-6.1-sol"] == summary.valuation.total)
        precondition(summary.usage.cachedInputKnown && summary.usage.reasoningKnown)
        precondition(summary.models[0].usage == summary.usage && summary.models[0].sessionCount == 1)
        precondition(summary.dailyTotals.reduce(TokenUsage()) { $0 + $1.usage } == summary.usage)
        precondition(summary.hourlyTotals.reduce(TokenUsage()) { $0 + $1.usage } == summary.usage)
        precondition(summary === store.summary(in: .today, now: now.addingTimeInterval(60)))
        let all = store.summary(in: .all, now: now)
        precondition(all !== summary && all.usage == summary.usage && all.hourlyTotals.isEmpty)
        let nextDay = store.summary(in: .today, now: now.addingTimeInterval(86400))
        precondition(nextDay.usage.isZero && nextDay !== summary)
        precondition(nextDay.valuation.total == CostEstimate())
        let todayAgain = store.summary(in: .today, now: now)
        precondition(todayAgain !== summary && todayAgain.usage == summary.usage)
        // Palette changes publish only the preference, without a scan or cache invalidation.
        var loadingEvents = 0
        var reportEvents = 0
        let loadingObserver = store.$loading.dropFirst().sink { _ in loadingEvents += 1 }
        let reportObserver = store.$snapshot.dropFirst().sink { _ in reportEvents += 1 }
        let paletteSuccess = store.lastSuccessfulRefresh
        store.palette = .blue
        precondition(defaults.string(forKey: "CodexStatsColorPalette") == "blue")
        await Task.yield()
        precondition(!store.loading && loadingEvents == 0 && reportEvents == 0)
        precondition(store.summary(in: .today, now: now) === todayAgain)
        precondition(store.lastSuccessfulRefresh == paletteSuccess && store.errorMessage == nil)
        precondition(store.rootPath == root.path && store.period == .today && !store.autoRefresh && store.refreshInterval == .seconds30)
        let reopenedDefaults = UserDefaults(suiteName: suite)!
        let restoredBlue = UsageStore(defaults: reopenedDefaults, priceFileURL: root.appendingPathComponent("prices.json"))
        precondition(restoredBlue.palette == .blue)
        await finish(restoredBlue)
        store.palette = .cyan
        precondition(defaults.string(forKey: "CodexStatsColorPalette") == "cyan")
        await Task.yield()
        precondition(!store.loading && loadingEvents == 0 && reportEvents == 0)
        precondition(store.summary(in: .today, now: now) === todayAgain && store.lastSuccessfulRefresh == paletteSuccess)
        let restoredCyan = UsageStore(defaults: UserDefaults(suiteName: suite)!, priceFileURL: root.appendingPathComponent("prices.json"))
        precondition(restoredCyan.palette == .cyan)
        await finish(restoredCyan)
        defaults.set("unknown-future-palette", forKey: "CodexStatsColorPalette")
        let unknownPalette = UsageStore(defaults: UserDefaults(suiteName: suite)!, priceFileURL: root.appendingPathComponent("prices.json"))
        precondition(unknownPalette.palette == .cyan)
        await finish(unknownPalette)
        defaults.removeObject(forKey: "CodexStatsColorPalette")
        let missingPalette = UsageStore(defaults: UserDefaults(suiteName: suite)!, priceFileURL: root.appendingPathComponent("prices.json"))
        precondition(missingPalette.palette == .cyan)
        await finish(missingPalette)
        loadingObserver.cancel()
        reportObserver.cancel()
        let utcKey = UsageStore.SummaryKey(generation: 1, period: .today, now: now, timeZone: TimeZone(secondsFromGMT: 0)!)
        let zoneKey = UsageStore.SummaryKey(generation: 1, period: .today, now: now, timeZone: TimeZone(secondsFromGMT: 3600)!)
        precondition(utcKey != zoneKey)
        // An accepted refresh replaces a same-day, same-period summary even if totals are unchanged.
        store.refresh()
        await finish(store)
        let refreshed = store.summary(in: .today, now: now)
        precondition(refreshed !== todayAgain && refreshed.usage == todayAgain.usage)
        let successful = store.lastSuccessfulRefresh
        try fm.removeItem(at: root)
        store.refresh()
        precondition(store.hasReport && store.report.totals(in: .all).total == 110)
        await finish(store)
        precondition(store.errorMessage != nil && store.lastSuccessfulRefresh == successful && store.hasReport)
        precondition(store.scanStatus.requiresAttention && store.scanStatus.summary == "刷新失败，保留上次成功数据")
        let previousError = store.errorMessage
        store.refresh()
        precondition(store.loading && store.errorMessage == previousError && store.scanStatus.requiresAttention)
        await finish(store)
        let retained = store.summary(in: .all, now: now)
        precondition(retained.usage.total == 110)
        precondition(retained.valuation.total == summary.valuation.total)
        store.updateRoot(root.appendingPathComponent("missing-new-root").path)
        let reset = store.summary(in: .all, now: now)
        precondition(reset !== retained && reset.usage.isZero)
        precondition(reset.valuation.total == CostEstimate() && reset.valuation.models.isEmpty)
        precondition(!store.didScan && !store.hasReport && store.errorMessage == nil && store.lastSuccessfulRefresh == nil)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        store.updateRoot(root.path)
        await finish(store)
        precondition(store.hasReport && store.report.totals(in: .all).isZero && store.errorMessage == nil)
        precondition(!store.scanStatus.requiresAttention)
        let incomplete = data.replacingOccurrences(of: ",\"cached_input_tokens\":90,\"reasoning_output_tokens\":5", with: "")
        try Data(incomplete.utf8).write(to: sessions.appendingPathComponent("incomplete.jsonl"))
        store.refresh()
        await finish(store)
        let unknown = store.summary(in: .all, now: now)
        precondition(unknown.valuation.total.state == .unavailable && unknown.valuation.total.unestimatedTokens == 110)
        precondition(unknown.usage.total == 110 && !unknown.usage.cachedInputKnown && !unknown.usage.reasoningKnown)
        precondition(!unknown.models[0].usage.cachedInputKnown && !unknown.dailyTotals[0].usage.reasoningKnown)
        precondition(store.scanStatus.warningCount > 0 && store.scanStatus.requiresAttention)
        precondition(store.scanStatus.sidebarText == "统计可能不完整")
        // Failed refresh keeps both the accepted report's risk and successful time, even while retrying.
        let riskCount = store.scanStatus.warningCount
        let riskSuccess = store.lastSuccessfulRefresh
        try fm.removeItem(at: root)
        store.refresh()
        precondition(store.scanStatus.warningCount == riskCount && store.scanStatus.requiresAttention)
        await finish(store)
        precondition(store.hasReport && store.lastSuccessfulRefresh == riskSuccess && store.errorMessage != nil)
        precondition(store.scanStatus.warningCount == riskCount)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        try Data(data.utf8).write(to: sessions.appendingPathComponent("known.jsonl"))
        let archive = root.appendingPathComponent("archived_sessions")
        try fm.createDirectory(at: archive, withIntermediateDirectories: true)
        try Data(data.utf8).write(to: archive.appendingPathComponent("known-copy.jsonl"))
        store.refresh()
        precondition(store.errorMessage != nil && store.scanStatus.warningCount == riskCount)
        await finish(store)
        precondition(store.errorMessage == nil && store.hasReport && store.lastSuccessfulRefresh != riskSuccess)
        precondition(store.report.totals(in: .all).total == 110)
        precondition(store.scanStatus.informationCount > 0 && store.scanStatus.warningCount == 0 && !store.scanStatus.requiresAttention)
        precondition(store.scanStatus.summary.hasPrefix("统计状态正常") && store.scanStatus.sidebarText == "本地数据已连接")
        // An obsolete scan cannot publish a result for a newly selected root.
        store.refresh()
        store.updateRoot(root.appendingPathComponent("missing-final-root").path)
        precondition(!store.didScan && !store.hasReport)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        precondition(pairedPublications >= 6)
        pairObserver.cancel()
        print("PASS: isolated palette default/unknown/restoration, actual cyan/blue switches with no loading/report publications and retained summary/time/path/range/timer settings; real scanner states; bounded summary reuse, range/day/timezone/report/root invalidation, value consistency, unknown fields, diagnostic severity, failure/retry retention and successful recovery")
    }
    @MainActor static func verifyOverview() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("overview-store-" + UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let suite = "overview-store-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot"); defaults.set(false, forKey: "CodexPulseAutoRefresh")
        let now = Date(), old = now.addingTimeInterval(-60 * 86400)
        for (i, row) in [("gpt-5.6-sol", now), ("gpt-6-sol", now), ("old-model", old)].enumerated() {
            let timestamp = ISO8601DateFormatter().string(from: row.1)
            let text = "{\"type\":\"session_meta\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"id\":\"s\(i)\",\"cwd\":\"/synthetic\"}}\n"
                + "{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"s\(i)\",\"response_id\":\"r-\(i)\",\"model\":\"\(row.0)\",\"usage\":{\"input_tokens\":1000,\"cached_input_tokens\":800,\"output_tokens\":100,\"reasoning_output_tokens\":0}}}\n"
            try Data(text.utf8).write(to: sessions.appendingPathComponent("s\(i).jsonl"))
        }
        let file = root.appendingPathComponent("prices.json")
        let own = try ModelPrice(model: "gpt-6-sol", input: "4", cachedInput: "0.4", output: "20")
        try PriceCatalogFile(url: file).save(PriceCatalog(entries: [own], revision: "existing-user-snapshot"))
        let store = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(store)
        precondition(store.catalog?.entries == [own] && store.newBuiltInPrices.map(\.model) == ["gpt-5.6-sol"])
        let unfiltered = store.summary(in: .today, now: now)
        let selection = "gpt-5.6-sol"
        let first = store.overviewSummary(model: selection, in: .today, now: now)
        precondition(first.data.recordCount == 1 && first.data.usage.total == 1100 && first.valuation.total.state == .unavailable)
        precondition(first.data.modelRecordCounts == ["gpt-5.6-sol": 1, "gpt-6-sol": 1])
        precondition(first === store.overviewSummary(model: selection, in: .today, now: now.addingTimeInterval(1)))
        let success = store.lastSuccessfulRefresh
        var scans = 0
        let observer = store.$loading.dropFirst().sink { _ in scans += 1 }
        store.palette = .blue
        precondition(first === store.overviewSummary(model: selection, in: .today, now: now))
        // A local model/range query does not mutate the unfiltered summary consumed by menu/other pages.
        precondition(store.summary(in: .today, now: now) === unfiltered)
        let oldSelection = store.overviewSummary(model: "old-model", in: .today, now: now)
        precondition(oldSelection.data.usage.isZero && oldSelection.data.recordCount == 0)
        precondition(store.overviewSummary(model: "old-model", in: .all, now: now).data.recordCount == 1)
        let all = store.overviewSummary(in: .all, now: now)
        precondition(all.data.usage == store.report.totals(in: .all, now: now) && all.data.recordCount == 3)
        let missing = store.overviewSummary(model: "gone-model", in: .today, now: now)
        precondition(missing.data.usage.isZero && missing.data.models.isEmpty)
        _ = store.overviewSummary(model: selection, in: .today, now: now)
        let pairedObserver = store.$snapshot.dropFirst().sink { _ in
            _ = store.overviewSummary(model: selection, in: .today, now: now)
        }
        let importSucceeded = await store.addNewBuiltInPrices(); precondition(importSucceeded)
        let imported = store.overviewSummary(model: selection, in: .today, now: now)
        precondition(imported !== first && imported.valuation.total.exactUSD == "0.00312")
        precondition(first.valuation.hourly.values.first?.state == .unavailable)
        precondition(imported.valuation.hourly.values.first?.exactUSD == "0.00312")
        precondition(imported.valuation.daily.values.first?.exactUSD == "0.00312")
        precondition(imported.data.hourlyRecordCounts.values.reduce(0, +) == 1 && imported.data.dailyRecordCounts.values.reduce(0, +) == 1)
        precondition(imported.data.usage == first.data.usage && imported.data.recordCount == 1)
        precondition(store.catalog?.entry(for: "gpt-6-sol") == own && store.catalog?.entries.count == 2)
        precondition(store.catalog?.entry(for: "gpt-6.1-sol") == nil && store.catalog?.entry(for: "codex-auto-review") == nil)
        precondition(scans == 0 && store.lastSuccessfulRefresh == success)
        let reopened = UsageStore(defaults: defaults, priceFileURL: file); await finish(reopened)
        precondition(reopened.newBuiltInPrices.isEmpty && reopened.catalog == store.catalog)
        let editSucceeded = await store.savePrice(model: selection, input: "2", cachedInput: "0.2", output: "10", adding: false); precondition(editSucceeded)
        let repricedTrend = store.overviewSummary(model: selection, in: .today, now: now)
        precondition(repricedTrend.valuation.total.exactUSD == "0.00156")
        precondition(repricedTrend.valuation.hourly.values.first?.exactUSD == "0.00156" && repricedTrend.valuation.daily.values.first?.exactUSD == "0.00156")
        precondition(repricedTrend.data.hourlyRecordCounts == imported.data.hourlyRecordCounts)
        precondition(store.lastSuccessfulRefresh == success && scans == 0)
        pairedObserver.cancel(); observer.cancel()
        // A real failed import must preserve the complete effective table and its derived snapshot.
        let empty = try PriceCatalog(entries: [])
        try PriceCatalogFile(url: file).save(empty); await store.reloadPrices()
        precondition(store.catalog == empty && store.newBuiltInPrices.count == 2)
        let before = store.overviewSummary(model: selection, in: .today, now: now)
        try fm.removeItem(at: file); try fm.createDirectory(at: file, withIntermediateDirectories: true)
        let failedImport = await store.addNewBuiltInPrices(); precondition(!failedImport)
        precondition(store.catalog == empty && store.priceError != nil)
        precondition(store.overviewSummary(model: selection, in: .today, now: now) === before)
        store.updateRoot(root.appendingPathComponent("missing").path)
        precondition(store.overviewSummary(model: selection, in: .today, now: now).data.usage.isZero)
        await finish(store)
        print("PASS: overview scalar model/range/count/zero queries, bounded identity and palette reuse, menu isolation, atomic reprice invalidation, explicit new-default import preserving custom/removed rows, persistence/save-failure retention; no query/import/edit rescan")
    }
    @MainActor static func verifyPrices() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("price-store-" + UUID().uuidString)
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let suite = "price-store-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        let file = root.appendingPathComponent("config/prices.json")
        let timestamp = "2025-01-01T12:00:00Z" // Outside today / 7 / 30 days: candidates/protection use all history.
        func write(_ name: String, model: String, input: Int = 1000) throws {
            let text = "{\"type\":\"session_meta\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"id\":\"\(name)\",\"cwd\":\"/synthetic\"}}\n"
                + "{\"type\":\"token_usage_record\",\"timestamp\":\"\(timestamp)\",\"payload\":{\"thread_id\":\"\(name)\",\"response_id\":\"r-\(name)\",\"model\":\"\(model)\",\"usage\":{\"input_tokens\":\(input),\"cached_input_tokens\":800,\"output_tokens\":100,\"reasoning_output_tokens\":0}}}\n"
            try Data(text.utf8).write(to: sessions.appendingPathComponent(name + ".jsonl"))
        }
        try write("new", model: "new-exact-model")
        try write("builtin", model: "gpt-6.1-sol")
        let store = UsageStore(defaults: defaults, priceFileURL: file)
        precondition(store.deletePriceBlockReason("gpt-6-luna") != nil)
        await finish(store)
        precondition(store.priceCandidates == ["new-exact-model"] && store.summary.usage.isZero)
        precondition(store.deletePriceBlockReason("gpt-6.1-sol") != nil)
        precondition(store.deletePriceBlockReason("gpt-6-luna") == nil)
        // Warnings cannot establish absence; a normal duplicate-history information diagnostic can.
        let damaged = sessions.appendingPathComponent("damaged.jsonl")
        try Data("damaged row\n".utf8).write(to: damaged)
        store.refresh(); await finish(store)
        precondition(store.scanStatus.warningCount > 0 && store.deletePriceBlockReason("gpt-6-luna") != nil)
        try fm.removeItem(at: damaged)
        let archive = root.appendingPathComponent("archived_sessions")
        try fm.createDirectory(at: archive, withIntermediateDirectories: true)
        try fm.copyItem(at: sessions.appendingPathComponent("builtin.jsonl"), to: archive.appendingPathComponent("builtin-copy.jsonl"))
        store.refresh(); await finish(store)
        precondition(store.scanStatus.warningCount == 0 && store.scanStatus.informationCount > 0)
        precondition(store.deletePriceBlockReason("gpt-6-luna") == nil)
        let original = store.summary(in: .all)
        let success = store.lastSuccessfulRefresh
        var scans = 0
        let observer = store.$loading.dropFirst().sink { _ in scans += 1 }
        let added = await store.savePrice(model: "new-exact-model", input: "2", cachedInput: "0.1", output: "10", adding: true)
        precondition(added && scans == 0 && store.lastSuccessfulRefresh == success)
        let priced = store.summary(in: .all)
        precondition(priced.usage == original.usage && priced.valuation.total.exactUSD == "0.00296")
        precondition(priced.valuation.total.priceSources == [.builtIn, .custom] && store.priceCandidates.isEmpty)
        precondition(store.deletePriceBlockReason("new-exact-model") != nil)
        let blockedBuiltin = await store.deletePrice("gpt-6.1-sol")
        let blockedCustom = await store.deletePrice("new-exact-model")
        precondition(!blockedBuiltin && !blockedCustom)
        let invalid = await store.savePrice(model: "new-exact-model", input: "bad", cachedInput: "0", output: "1", adding: false)
        precondition(!invalid && store.summary(in: .all) === priced)
        let duplicate = await store.savePrice(model: "new-exact-model", input: "0", cachedInput: "0", output: "0", adding: true)
        precondition(!duplicate)
        let edited = await store.savePrice(model: "new-exact-model", input: "0", cachedInput: "0", output: "0", adding: false)
        precondition(edited && store.summary(in: .all).valuation.total.exactUSD == "0.00148")
        let removed = await store.deletePrice("gpt-6-luna")
        precondition(removed && store.catalog?.entry(for: "gpt-6-luna") == nil)
        let reopened = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(reopened)
        precondition(reopened.catalog?.entry(for: "gpt-6-luna") == nil && reopened.priceCandidates.isEmpty)
        // Refresh/edit interleaving: the newly scanned report must use the latest persisted price.
        try write("new", model: "new-exact-model", input: 2000)
        store.refresh()
        let race = await store.savePrice(model: "new-exact-model", input: "3", cachedInput: "0.2", output: "11", adding: false)
        await finish(store)
        precondition(race && store.summary(in: .all).usage.total == 3200)
        precondition(store.summary(in: .all).valuation.total.exactUSD == "0.00634")
        precondition(store.snapshot.catalog?.revision == store.catalog?.revision)
        precondition(store.snapshot.valuation.catalogRevision == store.catalog?.revision)
        observer.cancel()
        // A directory at the destination causes an actual save failure; the prior catalog and snapshot survive.
        let oldCatalog = store.catalog, oldSummary = store.summary(in: .all)
        try fm.removeItem(at: file)
        try fm.createDirectory(at: file, withIntermediateDirectories: true)
        let failed = await store.savePrice(model: "new-exact-model", input: "9", cachedInput: "1", output: "20", adding: false)
        precondition(!failed && store.priceError != nil && store.catalog == oldCatalog && store.summary(in: .all) === oldSummary)
        let corrupt = UsageStore(defaults: defaults, priceFileURL: file)
        await finish(corrupt)
        precondition(corrupt.hasReport && corrupt.catalog == nil && corrupt.priceError != nil)
        precondition(corrupt.summary(in: .all).valuation.total.reasons == [.priceConfigurationUnavailable: 2])
        precondition(!corrupt.canAddPrice && corrupt.deletePriceBlockReason("gpt-6-luna") != nil)
        // Missing logs and warning reports do not prove absence, even for an unused built-in entry.
        store.updateRoot(root.appendingPathComponent("missing").path)
        await finish(store)
        precondition(store.deletePriceBlockReason("gpt-6-astra") != nil)
        print("PASS: all-history candidates, built-in/custom delete parity, persistent deletion, add/edit/zero/validation, no rescan, atomic scan/edit race, saved revision pairing, failed-save retention, corrupt-config unavailable amounts and uncertain-history deletion protection")
    }
    @MainActor static func finish(_ store: UsageStore) async {
        let deadline = Date().addingTimeInterval(10)
        while store.loading {
            precondition(Date() < deadline, "UsageStore scan timed out")
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
