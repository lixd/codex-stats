import Foundation

@main struct StoreVerification {
    @MainActor static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("codex-stats-store-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions")
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let data = """
        {"type":"session_meta","timestamp":"2026-10-14T00:00:00Z","payload":{"id":"synthetic-store","cwd":"/synthetic"}}
        {"type":"token_usage_record","timestamp":"2026-10-14T12:00:01.123Z","payload":{"thread_id":"synthetic-store","response_id":"r","model":"synthetic-model","usage":{"input_tokens":100,"output_tokens":10,"cached_input_tokens":90,"reasoning_output_tokens":5}}}

        """
        try Data(data.utf8).write(to: sessions.appendingPathComponent("store.jsonl"))
        let suite = "codex-stats-store-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(root.path, forKey: "CodexPulseRoot")
        defaults.set(false, forKey: "CodexPulseAutoRefresh")
        let store = UsageStore(defaults: defaults)
        precondition(store.loading && !store.didScan && !store.hasReport && store.lastSuccessfulRefresh == nil)
        await finish(store)
        precondition(store.didScan && store.hasReport && store.errorMessage == nil)
        precondition(store.report.totals(in: .all).total == 110)
        let now = ISO8601DateFormatter().date(from: "2026-10-14T12:30:00Z")!

        let summary = store.summary(in: .today, now: now)
        precondition(summary.usage.total == 110 && summary.models.count == 1)
        precondition(summary.usage.cachedInputKnown && summary.usage.reasoningKnown)
        precondition(summary.models[0].usage == summary.usage && summary.models[0].sessionCount == 1)
        precondition(summary.dailyTotals.reduce(TokenUsage()) { $0 + $1.usage } == summary.usage)
        precondition(summary.hourlyTotals.reduce(TokenUsage()) { $0 + $1.usage } == summary.usage)
        precondition(summary === store.summary(in: .today, now: now.addingTimeInterval(60)))
        let all = store.summary(in: .all, now: now)
        precondition(all !== summary && all.usage == summary.usage && all.hourlyTotals.isEmpty)
        let nextDay = store.summary(in: .today, now: now.addingTimeInterval(86400))
        precondition(nextDay.usage.isZero && nextDay !== summary)
        let todayAgain = store.summary(in: .today, now: now)
        precondition(todayAgain !== summary && todayAgain.usage == summary.usage)
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
        let retained = store.summary(in: .all, now: now)
        precondition(retained.usage.total == 110)
        store.updateRoot(root.appendingPathComponent("missing-new-root").path)
        let reset = store.summary(in: .all, now: now)
        precondition(reset !== retained && reset.usage.isZero)
        precondition(!store.didScan && !store.hasReport && store.errorMessage == nil && store.lastSuccessfulRefresh == nil)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        store.updateRoot(root.path)
        await finish(store)
        precondition(store.hasReport && store.report.totals(in: .all).isZero && store.errorMessage == nil)
        let incomplete = data.replacingOccurrences(of: ",\"cached_input_tokens\":90,\"reasoning_output_tokens\":5", with: "")
        try Data(incomplete.utf8).write(to: sessions.appendingPathComponent("incomplete.jsonl"))
        store.refresh()
        await finish(store)
        let unknown = store.summary(in: .all, now: now)
        precondition(unknown.usage.total == 110 && !unknown.usage.cachedInputKnown && !unknown.usage.reasoningKnown)
        precondition(!unknown.models[0].usage.cachedInputKnown && !unknown.dailyTotals[0].usage.reasoningKnown)
        // An obsolete scan cannot publish a result for a newly selected root.
        store.refresh()
        store.updateRoot(root.appendingPathComponent("missing-final-root").path)
        precondition(!store.didScan && !store.hasReport)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        print("PASS: real scanner states; bounded summary reuse, range/day/timezone/report/root invalidation, value consistency and unknown field flags")
    }
    @MainActor static func finish(_ store: UsageStore) async {
        let deadline = Date().addingTimeInterval(10)
        while store.loading {
            precondition(Date() < deadline, "UsageStore scan timed out")
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
