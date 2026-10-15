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
