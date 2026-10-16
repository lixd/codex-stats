import Foundation

@main
struct ValuationScale {
    static func main() {
        let modelIDs = ["gpt-6.1-sol", "gpt-6-astra", "gpt-6-luna", "gpt-5.3-codex"]
        let date = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!
        let usage = TokenUsage(input: 1000, cachedInput: 800, output: 100)
        let sessions = (0..<100).map { sessionIndex -> SessionUsage in
            let id = "synthetic-\(sessionIndex)"
            let records = (0..<1000).map { index in
                UsageRecord(id: "\(id)-\(index)", sessionID: id, recordedSessionID: id, project: "synthetic", source: "scale",
                            fileName: "synthetic", timestamp: date, day: "2026-10-\(String(format: "%02d", 6 + (index / 4) % 10))",
                            model: modelIDs[index % 4], requestID: nil, turnID: nil, usage: usage, evidence: .responseRecord,
                            isCompaction: false, cumulativeSnapshot: nil, lastReportedUsage: nil)
            }
            return SessionUsage(id: id, project: "synthetic", title: id, workingDirectory: "", source: "scale", isFork: false,
                                replayDeduplicated: false, replayUnverified: false, firstActivity: date, lastActivity: date,
                                dailyModel: [], fileName: "synthetic", records: records)
        }
        let report = ScanReport(sessions: sessions, fileCount: 100, invalidLineCount: 0, diagnostics: [], refreshedAt: date)
        let clock = ContinuousClock()
        let buildStart = clock.now
        let index = ValuationIndex(report: report)
        let buildTime = buildStart.duration(to: clock.now)
        let mergeStart = clock.now
        let summary = index.summary(in: .all, now: date)
        let mergeTime = mergeStart.duration(to: clock.now)
        precondition(index.bucketCount == 4000)
        precondition(summary.total.amountUSD == Decimal(string: "281.2")!)
        precondition(summary.total.estimatedTokens == 110_000_000 && summary.total.unestimatedTokens == 0)
        print("PASS: optimized synthetic 100000 accepted records, 100 sessions, 10 days, 4 models, 4000 scalar buckets; build=\(buildTime), one all-range merge=\(mergeTime), exactUSD=\(summary.total.exactUSD)")
    }
}
