import Foundation
import Testing
@testable import CodexStatsCore

private func overviewReport(_ rows: [(String, String, String, TokenUsage)], timeZone: TimeZone) -> ScanReport {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
    let formatter = DateFormatter()
    formatter.calendar = calendar; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = timeZone; formatter.dateFormat = "yyyy-MM-dd"
    let records = rows.enumerated().map { i, row in
        let date = ISO8601DateFormatter().date(from: row.2)!
        return UsageRecord(id: "r\(i)", sessionID: row.0, recordedSessionID: row.0, project: "synthetic", source: "test", fileName: "synthetic",
            timestamp: date, day: formatter.string(from: date), model: row.1, requestID: "r\(i)", turnID: nil,
            usage: row.3, evidence: .responseRecord, isCompaction: false, cumulativeSnapshot: nil, lastReportedUsage: nil)
    }
    let sessions = Dictionary(grouping: records, by: \.sessionID).map { id, records in
        var hours: [Date: TokenUsage] = [:]
        for record in records { hours[calendar.dateInterval(of: .hour, for: record.timestamp)!.start, default: TokenUsage()] += record.usage }
        return SessionUsage(id: id, project: "synthetic", title: id, workingDirectory: "", source: "test", isFork: false,
            replayDeduplicated: false, replayUnverified: false, firstActivity: records.first!.timestamp, lastActivity: records.last!.timestamp,
            dailyModel: records.map { DailyModelUsage(day: $0.day, model: $0.model, usage: $0.usage) }, fileName: "synthetic", hourlyUsage: hours, records: records)
    }
    return ScanReport(sessions: sessions, fileCount: sessions.count, invalidLineCount: 0, diagnostics: [], refreshedAt: Date())
}

@Test func overviewFilteredBucketsAgreeWithAcceptedRecordsAcrossEveryRange() {
    let zone = TimeZone(secondsFromGMT: 0)!
    let report = overviewReport([
        ("a", "gpt-5.6-sol", "2026-10-15T00:00:00Z", TokenUsage(input: 1000, cachedInput: 800, output: 100)),
        ("a", "gpt-6-sol", "2026-10-15T12:00:00Z", TokenUsage(input: 900, cachedInput: 0, output: 50)),
        ("b", "gpt-5.6-sol", "2026-10-14T23:59:59Z", TokenUsage(input: 100, cachedInput: 100, output: 10)),
        ("a", "gpt-5.6-sol", "2026-10-15T01:00:00Z", TokenUsage(input: 500, output: 10, cachedInputKnown: false)),
        ("b", "Unknown model", "2026-09-01T12:00:00Z", TokenUsage(output: 100)),
        ("b", "codex-auto-review", "2026-10-16T12:00:00Z", TokenUsage(input: 200))
    ], timeZone: zone)
    let now = ISO8601DateFormatter().date(from: "2026-10-15T13:00:00Z")!
    let index = OverviewIndex(report: report, timeZone: zone), values = ValuationIndex(report: report, timeZone: zone)
    #expect(index.observedModels == ["Unknown model", "codex-auto-review", "gpt-5.6-sol", "gpt-6-sol"])
    for period in UsagePeriod.allCases {
        let all = index.summary(in: period, now: now, timeZone: zone)
        #expect(all.usage == report.totals(in: period, now: now))
        #expect(all.recordCount == report.records(in: period, now: now).count)
        #expect(all.modelRecordCounts.values.reduce(0, +) == all.recordCount)
        for model in index.observedModels + ["gone-model"] {
            let result = index.summary(in: period, model: model, now: now, timeZone: zone)
            let records = report.records(in: period, now: now).filter { $0.model == model }
            let expected = records.reduce(TokenUsage()) { $0 + $1.usage }
            #expect(result.usage == expected && result.recordCount == records.count)
            #expect(result.modelRecordCounts == all.modelRecordCounts)
            #expect(result.dailyRecordCounts.values.reduce(0, +) == records.count)
            #expect(result.dailyRecordCounts.keys.sorted() == result.dailyTotals.map(\.day))
            #expect(result.dailyTotals.reduce(TokenUsage()) { $0 + $1.usage } == expected)
            #expect(result.models.reduce(TokenUsage()) { $0 + $1.usage } == expected)
            #expect(result.models.first?.sessionCount ?? 0 == Set(records.map(\.sessionID)).count)
            if period == .today {
                #expect(result.hourlyTotals.reduce(TokenUsage()) { $0 + $1.usage } == expected)
                #expect(result.hourlyRecordCounts.values.reduce(0, +) == records.count)
            }
            else { #expect(result.hourlyTotals.isEmpty) }
            let valuation = values.summary(in: period, model: model, now: now, timeZone: zone)
            let cost = valuation.total
            var dailyCost = CostEstimate()
            for value in valuation.daily.values { dailyCost.merge(value) }
            #expect(dailyCost == cost)
            if period == .today {
                var hourlyCost = CostEstimate()
                for value in valuation.hourly.values { hourlyCost.merge(value) }
                #expect(hourlyCost == cost)
            }
            var direct = CostEstimate()
            for record in records { direct.merge(.calculate(usage: record.usage, model: model)) }
            #expect(cost == direct)
        }
    }
    let today = index.summary(in: .today, model: "gpt-5.6-sol", now: now, timeZone: zone)
    #expect(CacheRate(usage: today.usage).state == .incomplete)
    let cost = values.summary(in: .today, model: "gpt-5.6-sol", now: now, timeZone: zone).total
    #expect(cost.exactUSD == "0.00312" && cost.state == .partial && cost.unestimatedTokens == 510)
    #expect(values.summary(in: .all, model: "codex-auto-review").total.reasons == [.missingPrice: 1])
}

@Test func overviewHoursRespectDSTAndLocalMidnightWithoutChangingModelTotals() {
    let zone = TimeZone(identifier: "America/New_York")!
    for (dates, count) in [(["2026-03-08T06:30:00Z", "2026-03-08T07:30:00Z"], 23),
                           (["2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z"], 25)] {
        let report = overviewReport(dates.map { ("s", "gpt-6-sol", $0, TokenUsage(input: 100, cachedInput: 0)) }, timeZone: zone)
        let now = ISO8601DateFormatter().date(from: dates.last!)!
        let result = OverviewIndex(report: report, timeZone: zone).summary(in: .today, model: "gpt-6-sol", now: now, timeZone: zone)
        let valuation = ValuationIndex(report: report, timeZone: zone).summary(in: .today, now: now, timeZone: zone)
        #expect(result.hourlyRecordCounts.count == 2 && result.hourlyRecordCounts.values.reduce(0, +) == 2)
        #expect(valuation.hourly.count == 2 && valuation.hourly.values.allSatisfy { $0.exactUSD == "0.0002" })
        #expect(valuation.total.exactUSD == "0.0004")
        #expect(result.hourlyTotals.count == count)
        #expect(result.recordCount == 2 && result.usage.input == 200)
        #expect(result.hourlyTotals.filter { !$0.usage.isZero }.count == 2)
        #expect(result.hourlyTotals.map(\.usage) == report.hourlyTotals(on: now, timeZone: zone).map(\.usage))
        #expect(OverviewIndex(report: report, timeZone: zone).summary(in: .today, now: now.addingTimeInterval(86400), timeZone: zone).usage.isZero)
    }
}

@Test func newBuiltinImportIsExplicitAndPreservesUserTableAndDeletion() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = PriceCatalogFile(url: root.appendingPathComponent("prices.json"))
    #expect(try file.load().entries.count == 6)
    let own = try ModelPrice(model: "gpt-6-sol", input: "99", cachedInput: "0", output: "77")
    let old = try PriceCatalog(entries: [own], revision: "saved-old")
    try file.save(old)
    #expect(try file.load() == old) // No automatic merge, including an empty table.
    #expect(old.missingNewBuiltIns.map(\.model) == ["gpt-5.6-sol"])
    let imported = try old.addingNewBuiltIns()
    #expect(imported.entries.count == 2 && imported.entry(for: "gpt-6-sol") == own)
    #expect(imported.entry(for: "gpt-6.1-sol") == nil && imported.entry(for: "codex-auto-review") == nil)
    #expect(imported.entry(for: "gpt-5.6-sol")?.sourceURL == ReferencePricing.source)
    #expect(PriceCatalog.builtIn.entry(for: "gpt-6-sol")?.sourceURL == ReferencePricing.changelogSource)
    try file.save(imported.removing("gpt-5.6-sol"))
    #expect(try file.load().entry(for: "gpt-5.6-sol") == nil)
    let empty = try PriceCatalog(entries: [], revision: "saved-empty")
    try file.save(empty)
    #expect(try file.load().entries.isEmpty && file.load().missingNewBuiltIns.count == 2)
}

@Test func trendBucketsKeepUnknownZeroAndMicroAmountsDistinct() throws {
    let zone = TimeZone(secondsFromGMT: 0)!
    let report = overviewReport([
        ("s", "priced", "2026-10-16T01:00:00Z", TokenUsage(input: 1, cachedInput: 0)),
        ("s", "missing", "2026-10-16T01:30:00Z", TokenUsage(input: 10)),
        ("s", "missing", "2026-10-16T02:00:00Z", TokenUsage(output: 20)),
        ("s", "free", "2026-10-16T03:00:00Z", TokenUsage(input: 5, cachedInput: 0)),
        ("s", "missing", "2026-10-15T23:59:59Z", TokenUsage(output: 30))
    ], timeZone: zone)
    let catalog = try PriceCatalog(entries: [ModelPrice(model: "priced", input: "0.01", cachedInput: "0", output: "1"),
                                           ModelPrice(model: "free", input: "0", cachedInput: "0", output: "0")], revision: "micro-zero")
    let now = ISO8601DateFormatter().date(from: "2026-10-16T12:00:00Z")!
    let result = ValuationIndex(report: report, catalog: catalog, timeZone: zone).summary(in: .today, now: now, timeZone: zone)
    let hour = ISO8601DateFormatter().date(from: "2026-10-16T01:00:00Z")!
    #expect(result.total.exactUSD == "0.00000001" && result.total.state == .partial)
    #expect(result.total.estimatedTokens == 6 && result.total.unestimatedTokens == 30)
    #expect(result.hourly[hour]?.state == .partial && result.hourly[hour]?.exactUSD == "0.00000001")
    #expect(result.hourly[hour.addingTimeInterval(3600)]?.state == .unavailable)
    #expect(result.hourly[hour.addingTimeInterval(7200)]?.state == .complete)
    #expect(result.hourly[hour.addingTimeInterval(7200)]?.exactUSD == "0")
    #expect(result.daily.keys.sorted() == ["2026-10-16"])
    let counts = OverviewIndex(report: report, timeZone: zone).summary(in: .today, now: now, timeZone: zone)
    #expect(counts.recordCount == 4 && counts.dailyRecordCounts == ["2026-10-16": 4])
    #expect(counts.hourlyRecordCounts[hour] == 2)
    let unpriced = ValuationIndex(report: report, catalog: catalog, timeZone: zone).summary(in: .today, model: "missing", now: now, timeZone: zone)
    #expect(unpriced.total.state == .unavailable && unpriced.total.unestimatedTokens == 30)
}
