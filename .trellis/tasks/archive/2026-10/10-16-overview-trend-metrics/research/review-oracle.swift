import Foundation

func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
let zone = TimeZone(identifier: "Asia/Shanghai")!
let now = date("2026-10-16T04:00:00Z")
let catalog = try PriceCatalog(entries: [
    ModelPrice(model: "A", input: "2", cachedInput: "0.2", output: "10"),
    ModelPrice(model: "Z", input: "0", cachedInput: "0", output: "0")
], revision: "independent-fixed-v1")
func report(_ rows: [(String, String, TokenUsage)], zone: TimeZone) -> ScanReport {
    let fmt = DateFormatter(); fmt.calendar = Calendar(identifier: .gregorian); fmt.timeZone = zone; fmt.locale = Locale(identifier: "en_US_POSIX"); fmt.dateFormat = "yyyy-MM-dd"
    let records = rows.enumerated().map { i, row in
        UsageRecord(id: "independent-\(i)", sessionID: "independent", recordedSessionID: nil, project: "synthetic", source: "oracle", fileName: "none", timestamp: date(row.1), day: fmt.string(from: date(row.1)), model: row.0, requestID: nil, turnID: nil, usage: row.2, evidence: .cumulativeDelta, isCompaction: false, cumulativeSnapshot: nil, lastReportedUsage: nil)
    }
    let session = SessionUsage(id: "independent", project: "synthetic", title: "synthetic", workingDirectory: "", source: "oracle", isFork: false, replayDeduplicated: false, replayUnverified: false, firstActivity: records.first!.timestamp, lastActivity: records.last!.timestamp, dailyModel: records.map { DailyModelUsage(day: $0.day, model: $0.model, usage: $0.usage) }, fileName: "none", records: records)
    return ScanReport(sessions: [session], fileCount: 0, invalidLineCount: 0, diagnostics: [], refreshedAt: now)
}
let fixture = report([
    ("A", "2026-10-15T16:15:00Z", TokenUsage(input: 1000, cachedInput: 800, output: 100)),
    ("A", "2026-10-15T16:45:00Z", TokenUsage(input: 500, output: 50)),
    ("U", "2026-10-15T16:50:00Z", TokenUsage(output: 100)),
    ("A", "2026-10-15T17:10:00Z", TokenUsage(input: 100, output: 10, cachedInputKnown: false)),
    ("Z", "2026-10-15T18:00:00Z", TokenUsage(input: 10, cachedInput: 5, output: 1)),
    ("A", "2026-10-15T19:00:00Z", TokenUsage(output: 1)),
    ("A", "2026-10-15T15:59:59Z", TokenUsage(input: 100, cachedInput: 100, output: 10)),
    ("U", "2026-09-01T01:00:00Z", TokenUsage(output: 5))
], zone: zone)
let usage = OverviewIndex(report: fixture, timeZone: zone)
let valuation = ValuationIndex(report: fixture, catalog: catalog, timeZone: zone)
func check(_ ok: @autoclosure () -> Bool, _ message: String) { precondition(ok(), message); print("PASS \(message)") }
// Literal expected values were computed before compilation, without calling the calculator.
for (period, count, tokens, amount, excluded) in [(UsagePeriod.today, 6, Int64(1872), "0.00307", Int64(210)), (.sevenDays, 7, 1982, "0.00319", 210), (.thirtyDays, 7, 1982, "0.00319", 210), (.all, 8, 1987, "0.00319", 215)] {
    let u = usage.summary(in: period, now: now, timeZone: zone), v = valuation.summary(in: period, now: now, timeZone: zone)
    check(u.recordCount == count && u.usage.total == tokens, "\(period) literal count/token")
    check(v.total.amountUSD == Decimal(string: amount)! && v.total.unestimatedTokens == excluded && v.total.state == .partial, "\(period) literal Decimal and coverage")
    check(u.dailyRecordCounts.values.reduce(0,+) == count, "\(period) daily count sum")
    check(v.daily.values.reduce(Decimal(0)) { $0 + $1.amountUSD } == Decimal(string: amount)!, "\(period) daily money sum")
}
let today = usage.summary(in: .today, now: now, timeZone: zone), money = valuation.summary(in: .today, now: now, timeZone: zone)
check(today.hourlyTotals.count == 24, "Shanghai 24 hours")
for (stamp, count, amount, state, excluded) in [("2026-10-15T16:00:00Z",3,"0.00306",CostEstimate.State.partial,Int64(100)),("2026-10-15T17:00:00Z",1,"0",.unavailable,110),("2026-10-15T18:00:00Z",1,"0",.complete,0),("2026-10-15T19:00:00Z",1,"0.00001",.complete,0)] {
    let h = date(stamp), v = money.hourly[h]!
    check(today.hourlyRecordCounts[h] == count, "hour \(stamp) count")
    check(v.amountUSD == Decimal(string: amount)! && v.state == state && v.unestimatedTokens == excluded, "hour \(stamp) exact money/state")
}
check(today.hourlyRecordCounts.values.reduce(0,+) == 6, "today hourly count sum")
check(money.hourly.values.reduce(Decimal(0)) { $0 + $1.amountUSD } == Decimal(string:"0.00307")!, "today hourly Decimal sum")
for (model,count,tokens,state) in [("A",4,Int64(1761),CostEstimate.State.partial),("U",1,100,.unavailable),("Z",1,11,.complete),("absent",0,0,.complete)] {
    let u = usage.summary(in: .today, model: model, now: now, timeZone: zone), v = valuation.summary(in:.today, model:model, now:now,timeZone:zone)
    check(u.recordCount == count && u.usage.total == tokens && v.total.state == state, "model \(model) filter count/token/state")
    check(u.dailyRecordCounts.values.reduce(0,+) == count && u.hourlyRecordCounts.values.reduce(0,+) == count, "model \(model) day/hour count agreement")
}
let repriced = try catalog.setting(ModelPrice(model:"A", input:"4",cachedInput:"0.4",output:"20"))
let changed = ValuationIndex(report: fixture, catalog: repriced, timeZone: zone).summary(in:.today,now:now,timeZone:zone)
check(changed.total.amountUSD == Decimal(string:"0.00614")! && changed.total.unestimatedTokens == 210, "repricing doubles A only; unknown unchanged")
let dstZone = TimeZone(identifier:"America/New_York")!
for (stamps, expectedHours) in [(["2026-03-08T06:30:00Z","2026-03-08T07:30:00Z"],23),(["2026-11-01T05:30:00Z","2026-11-01T06:30:00Z"],25)] {
    let r = report(stamps.map { ("A",$0,TokenUsage(output:1)) }, zone:dstZone)
    let u = OverviewIndex(report:r,timeZone:dstZone).summary(in:.today,now:date(stamps.last!),timeZone:dstZone)
    let v = ValuationIndex(report:r,catalog:catalog,timeZone:dstZone).summary(in:.today,now:date(stamps.last!),timeZone:dstZone)
    check(u.hourlyTotals.count == expectedHours && u.hourlyRecordCounts.count == 2 && u.hourlyRecordCounts.values.reduce(0,+) == 2,"DST \(expectedHours) distinct count hours")
    check(v.hourly.count == 2 && v.total.amountUSD == Decimal(string:"0.00002")! && v.hourly.values.allSatisfy { $0.amountUSD == Decimal(string:"0.00001")! },"DST \(expectedHours) distinct exact money hours")
}
print("Independent hand oracle complete; no real files/defaults/scanner used")
