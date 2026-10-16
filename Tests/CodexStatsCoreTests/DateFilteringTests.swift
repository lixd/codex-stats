import Foundation
import Testing
@testable import CodexStatsCore

@Test func timestampParsingPreservesMillisecondFormatterContract() {
    let scanner = CodexLogScanner()
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let whole = ISO8601DateFormatter()
    for raw in ["2026-10-14T00:00:00Z", "2026-10-14T00:00:00.1Z", "2026-10-14T00:00:00.12Z",
                "2026-10-14T00:00:00.123Z", "2026-10-14T00:00:00.123456789Z",
                "2026-10-13T23:59:59.999999Z", "2026-10-14T00:00:00.123+08:00",
                "2026-10-13T16:00:00.123Z", "1969-12-31T23:59:59.123456Z",
                "1969-12-31T23:59:59.9999Z", "garbage", "2026-10-14T00:00:00"] {
        let old = fractional.date(from: raw) ?? whole.date(from: raw)
        #expect(scanner.parseTimestamp(raw) == old, "\(raw)")
    }
    #expect(scanner.parseTimestamp("2026-10-14T00:00:00.123+08:00") == scanner.parseTimestamp("2026-10-13T16:00:00.123Z"))
}

@Test func operationBoundsRespectCalendarDaysFutureAndDST() throws {
    let zone = try #require(TimeZone(identifier: "America/New_York"))
    let now = try #require(ISO8601DateFormatter().date(from: "2026-03-09T03:59:59Z")) // March 8, 23:59 EDT
    let today = UsagePeriod.today.bounds(now: now, timeZone: zone)
    #expect(today.includes("2026-03-08"))
    #expect(!today.includes("2026-03-07"))
    #expect(!today.includes("2026-03-09"))
    let seven = UsagePeriod.sevenDays.bounds(now: now, timeZone: zone)
    #expect(seven.includes("2026-03-02"))
    #expect(!seven.includes("2026-03-01"))
    let thirty = UsagePeriod.thirtyDays.bounds(now: now, timeZone: zone)
    #expect(thirty.includes("2026-02-07"))
    #expect(!thirty.includes("2026-02-06"))
    #expect(UsagePeriod.all.bounds(now: now, timeZone: zone).includes("2027-01-01"))
    let midnight = try #require(ISO8601DateFormatter().date(from: "2026-03-09T04:00:00Z"))
    #expect(UsagePeriod.today.bounds(now: midnight, timeZone: zone).includes("2026-03-09"))
    #expect(!UsagePeriod.today.bounds(now: midnight, timeZone: zone).includes("2026-03-08"))
    let shanghai = try #require(TimeZone(identifier: "Asia/Shanghai"))
    #expect(UsagePeriod.today.bounds(now: now, timeZone: shanghai).includes("2026-03-09"))
}

@Test func timestampOutOfRangeClockComponentsStayInvalid() {
    let scanner = CodexLogScanner()
    let old = ISO8601DateFormatter()
    for raw in ["2026-10-14T25:00:00Z", "2026-10-14T00:60:00Z", "2026-10-14T00:00:60Z"] {
        #expect(old.date(from: raw) == nil)
        #expect(scanner.parseTimestamp(raw) == nil)
    }
    for raw in ["2024-02-29T12:34:56+08:00"] {
        #expect(scanner.parseTimestamp(raw) == old.date(from: raw))
    }
}

@Test func timestampRejectsFoundationCalendarAndOffsetNormalization() {
    let scanner = CodexLogScanner()
    let old = ISO8601DateFormatter()
    for raw in ["2026-10-14T24:00:00Z", "2026-10-14T24:01:00Z",
                "2026-02-29T00:00:00Z", "2026-02-30T00:00:00Z",
                "2026-10-14T00:00:00+24:00", "2026-10-14T00:00:00+08:60",
                "2026-10-14T00:00:00+99:00", "2026-10-14T00:00:00+1:00"] {
        #expect(old.date(from: raw) != nil, "Documents the intentionally rejected old normalization: \(raw)")
        #expect(scanner.parseTimestamp(raw) == nil)
    }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    for raw in ["2024-02-29T12:34:56+08:00", "2000-02-29T00:00:00Z",
                "2026-10-14T00:00:00+23:59", "2026-10-14T00:00:00-2359",
                "2026-10-14T00:00:00.123456+19:30", "1969-12-31T23:59:59.123-1930"] {
        #expect(scanner.parseTimestamp(raw) == (fractional.date(from: raw) ?? old.date(from: raw)))
    }
}

private func projectionSession(_ id: String, first: Date, last: Date, daily: [DailyModelUsage] = []) -> SessionUsage {
    SessionUsage(id: id, project: id, title: id, workingDirectory: "/synthetic/\(id)", source: "test",
                 isFork: false, replayDeduplicated: false, replayUnverified: false,
                 firstActivity: first, lastActivity: last, dailyModel: daily, fileName: "\(id).jsonl")
}

@Test func sessionProjectionPreservesActiveEmptySessionsAcrossDST() throws {
    let zone = try #require(TimeZone(identifier: "America/New_York"))
    let parser = ISO8601DateFormatter()
    // Both spring's 23-hour day and autumn's 25-hour day use local calendar bounds.
    for (startText, endText, day) in [("2026-03-08T05:00:00Z", "2026-03-09T04:00:00Z", "2026-03-08"),
                                      ("2026-11-01T04:00:00Z", "2026-11-02T05:00:00Z", "2026-11-01")] {
        let start = try #require(parser.date(from: startText))
        let end = try #require(parser.date(from: endText))
        let sessions = [
            projectionSession("end-excluded", first: end, last: end),
            projectionSession("first-in-range", first: start, last: end),
            projectionSession("last-in-range", first: start.addingTimeInterval(-1), last: end.addingTimeInterval(-1)),
            projectionSession("old", first: start.addingTimeInterval(-2), last: start.addingTimeInterval(-1)),
            projectionSession("usage-only", first: start.addingTimeInterval(-2), last: start.addingTimeInterval(-1),
                daily: [DailyModelUsage(day: day, model: "synthetic", usage: TokenUsage(input: 3, output: 2))])
        ]
        let report = ScanReport(sessions: sessions, fileCount: sessions.count, invalidLineCount: 0, diagnostics: [], refreshedAt: end)
        let rows = report.sessionRows(in: .today, now: end.addingTimeInterval(-1), timeZone: zone)
        #expect(rows.map(\.id) == ["first-in-range", "last-in-range", "usage-only"])
        #expect(rows[0].usage.isZero && rows[0].models.isEmpty)
        #expect(rows[2].usage.total == 5)
        // A new operation after midnight must not reuse the previous day's boundary.
        #expect(report.sessionRows(in: .today, now: end, timeZone: zone).map(\.id) == ["end-excluded", "first-in-range"])
    }
}

@Test func sessionProjectionAggregatesModelsUnknownFieldsAndAllDates() throws {
    let zone = try #require(TimeZone(identifier: "Asia/Shanghai"))
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-14T04:00:00Z"))
    let daily = [
        DailyModelUsage(day: "2026-10-14", model: "a", usage: TokenUsage(input: 10, cachedInput: 5, output: 4, reasoningKnown: false)),
        DailyModelUsage(day: "2026-10-13", model: "a", usage: TokenUsage(input: 20, output: 6, reasoning: 2, cachedInputKnown: false)),
        DailyModelUsage(day: "2026-10-08", model: "b", usage: TokenUsage(input: 30, output: 8)),
        DailyModelUsage(day: "2026-10-07", model: "c", usage: TokenUsage(input: 40, output: 10)),
        DailyModelUsage(day: "2026-09-15", model: "d", usage: TokenUsage(input: 50, output: 12)),
        DailyModelUsage(day: "2026-09-14", model: "e", usage: TokenUsage(input: 60, output: 14)),
        DailyModelUsage(day: "2026-10-15", model: "future", usage: TokenUsage(input: 70, output: 16))
    ]
    let session = projectionSession("usage", first: now, last: now, daily: daily)
    let report = ScanReport(sessions: [session], fileCount: 1, invalidLineCount: 0, diagnostics: [], refreshedAt: now)
    let expected: [(UsagePeriod, Int64, Set<String>)] = [
        (.today, 14, ["a"]), (.sevenDays, 78, ["a", "b"]),
        (.thirtyDays, 190, ["a", "b", "c", "d"]), (.all, 350, ["a", "b", "c", "d", "e", "future"])
    ]
    for (period, total, models) in expected {
        let row = try #require(report.sessionRows(in: period, now: now, timeZone: zone).first)
        #expect(row.usage.total == total)
        #expect(Set(row.models.map(\.model)) == models)
        #expect(row.models.reduce(TokenUsage()) { $0 + $1.usage } == row.usage)
        #expect(row.models.allSatisfy { $0.sessionCount == 1 })
        #expect(row.usage.cachedInputKnown == (period == .today))
        #expect(!row.usage.reasoningKnown)
    }
}

@Test func sessionProjectionUsesCapturedTimeZoneAndKeepsInputOrder() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-14T16:30:00Z"))
    let previousHour = now.addingTimeInterval(-3600)
    let sessions = [projectionSession("older", first: previousHour, last: previousHour),
                    projectionSession("newer", first: now, last: now)]
    let report = ScanReport(sessions: sessions, fileCount: 2, invalidLineCount: 0, diagnostics: [], refreshedAt: now)
    #expect(report.sessionRows(in: .today, now: now, timeZone: TimeZone(secondsFromGMT: 0)!).map(\.id) == ["older", "newer"])
    #expect(report.sessionRows(in: .today, now: now, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!).map(\.id) == ["newer"])
    #expect(report.sessionRows(in: .all, now: now, timeZone: TimeZone(secondsFromGMT: 8 * 3600)!).map(\.id) == ["older", "newer"])
}
