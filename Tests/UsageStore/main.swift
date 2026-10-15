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
        {"type":"token_usage_record","timestamp":"2026-10-14T00:00:01.123Z","payload":{"thread_id":"synthetic-store","response_id":"r","model":"synthetic-model","usage":{"input_tokens":100,"output_tokens":10,"cached_input_tokens":90,"reasoning_output_tokens":5}}}

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
        let successful = store.lastSuccessfulRefresh
        try fm.removeItem(at: root)
        store.refresh()
        precondition(store.hasReport && store.report.totals(in: .all).total == 110)
        await finish(store)
        precondition(store.errorMessage != nil && store.lastSuccessfulRefresh == successful && store.hasReport)
        store.updateRoot(root.appendingPathComponent("missing-new-root").path)
        precondition(!store.didScan && !store.hasReport && store.errorMessage == nil && store.lastSuccessfulRefresh == nil)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        try fm.createDirectory(at: sessions, withIntermediateDirectories: true)
        store.updateRoot(root.path)
        await finish(store)
        precondition(store.hasReport && store.report.totals(in: .all).isZero && store.errorMessage == nil)
        // An obsolete scan cannot publish a result for a newly selected root.
        store.refresh()
        store.updateRoot(root.appendingPathComponent("missing-final-root").path)
        precondition(!store.didScan && !store.hasReport)
        await finish(store)
        precondition(store.didScan && !store.hasReport && store.errorMessage != nil)
        print("PASS: real scanner first load, refresh retention, failure, root reset, zero and obsolete result states")
    }
    @MainActor static func finish(_ store: UsageStore) async {
        let deadline = Date().addingTimeInterval(10)
        while store.loading {
            precondition(Date() < deadline, "UsageStore scan timed out")
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
