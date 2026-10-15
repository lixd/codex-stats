import Foundation
import Testing
@testable import CodexStatsCore

private struct Logs {
    let root: URL
    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for folder in ["sessions", "archived_sessions"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
    }
    func remove() { try? FileManager.default.removeItem(at: root) }
    func write(_ lines: [[String: Any]], name: String = "rollout.jsonl", archived: Bool = false) throws {
        let url = root.appendingPathComponent(archived ? "archived_sessions" : "sessions").appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = Data()
        for line in lines { data.append(try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])); data.append(10) }
        try data.write(to: url)
    }
    func scan(_ scanner: CodexLogScanner = CodexLogScanner(timeZone: TimeZone(secondsFromGMT: 0)!)) throws -> ScanReport {
        let report = try scanner.scan(homePath: root.path)
        #expect(report.records(in: .all).reduce(TokenUsage()) { $0 + $1.usage } == report.totals(in: .all))
        #expect(Set(report.records(in: .all).map(\.id)).count == report.records(in: .all).count)
        for session in report.sessions {
            for model in session.modelUsage(in: .all) {
                #expect(session.records.filter { $0.model == model.model }.reduce(TokenUsage()) { $0 + $1.usage } == model.usage)
            }
        }
        return report
    }
}

@Test func requestRecordsPreserveIdentityAndConfirmedUsage() throws {
    let logs = try Logs(); defer { logs.remove() }
    let tokens = usage(1000, 100, cache: 900, reasoning: 50)
    let record = request("real-response", tokens, total: tokens, model: "model-A")
    try logs.write([meta(), turn(), record, count(tokens, last: tokens), record])
    let rows = try logs.scan().records(in: .all)
    #expect(rows.count == 1)
    let row = try #require(rows.first)
    #expect(row.requestID == "real-response")
    #expect(row.sessionID == "session")
    #expect(row.recordedSessionID == "session")
    #expect(row.turnID == "turn-A")
    #expect(row.evidence == .responseRecord)
    #expect(row.usage.uncachedInput == 100)
    #expect(row.usage.reasoning == 50)
    #expect(row.cumulativeSnapshot?.total == 1100)
}

@Test func legacyAccountingRowsDoNotInventRequestIdentity() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), count(usage(300, 30)),
        count(usage(350, 35), last: usage(50, 5))])
    let report = try logs.scan()
    #expect(report.sessions[0].records.map(\.evidence) == [.initialSnapshot, .cumulativeDelta, .lastUsage])
    #expect(report.records(in: .all).allSatisfy { $0.requestID == nil })
    #expect(report.sessions[0].records.map { $0.usage.total } == [110, 220, 55])
}

@Test func requestRowsRespectPeriodsAndSwitches() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), last: usage(100), at: "2026-10-13T23:59:00Z"),
        turn("model-B"), count(usage(200, 20), last: usage(100), at: "2026-10-14T00:01:00Z")])
    let report = try logs.scan()
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z"))
    for period in UsagePeriod.allCases {
        #expect(report.records(in: period, now: now).reduce(TokenUsage()) { $0 + $1.usage } == report.totals(in: period, now: now))
    }
    #expect(report.sessions[0].records.map(\.model) == ["model-A", "model-B"])
}

@Test func requestRowsRetainUnknownFields() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), count(["input_tokens": 100, "output_tokens": 10])])
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.model == "Unknown model")
    #expect(row.requestID == nil)
    #expect(row.turnID == nil)
    #expect(!row.usage.cachedInputKnown)
    #expect(!row.usage.reasoningKnown)
}

@Test func turnCompletedEventIDIsNotPresentedAsResponseID() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), ["type": "turn.completed", "id": "event-id",
        "timestamp": "2026-10-13T09:02:00Z", "usage": usage(100)]])
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.requestID == nil)
    #expect(row.evidence == .lastUsage)
}

@Test func requestRowsExcludeArchiveReplayAndMarkCompaction() throws {
    let logs = try Logs(); defer { logs.remove() }
    let record = request("compact-response", usage(30, 3), total: usage(130, 13))
    let lines = [meta(), turn(), count(usage(100)), record,
        count(usage(130, 13), last: usage(30, 3)), compact("compact-response")]
    try logs.write(lines)
    try logs.write(lines, name: "archive.jsonl", archived: true)
    let rows = try logs.scan().records(in: .all)
    #expect(rows.count == 2)
    let compaction = try #require(rows.first { $0.requestID == "compact-response" })
    #expect(compaction.isCompaction)
    #expect(compaction.model == "Unknown model")
    #expect(compaction.usage.total == 33)
}

@Test func missingSessionMetadataIsNotPresentedAsRecordedIdentity() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([count(usage(100))], name: "local-group.jsonl")
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.sessionID.hasPrefix("unidentified:"))
    #expect(row.sessionID == "unidentified:local-group")
    let session = try #require(try logs.scan().sessions.first)
    #expect(session.recordedSessionID == nil)
    #expect(session.title == "未识别项目 · 未记录 ID")
    #expect(row.recordedSessionID == nil)
    #expect(row.requestID == nil)
}
private func meta(_ id: String = "session", parent: String? = nil, history: Bool = false) -> [String: Any] {
    var p: [String: Any] = ["id": id, "cwd": "/work/project", "timestamp": "2026-10-13T09:00:00Z"]
    if let parent { p["forked_from_id"] = parent }
    if history { p["history_base"] = ["thread_id": id, "end_ordinal_exclusive": 99] }
    return ["type": "session_meta", "timestamp": "2026-10-13T09:00:00Z", "payload": p]
}
private func turn(_ model: String? = "model-A", id: String = "turn-A") -> [String: Any] {
    var p: [String: Any] = ["turn_id": id]
    if let model { p["model"] = model }
    return ["type": "turn_context", "timestamp": "2026-10-13T09:00:01Z", "payload": p]
}
private func usage(_ input: Int, _ output: Int = 10, cache: Int = 0, reasoning: Int = 0) -> [String: Any] {
    ["input_tokens": input, "cached_input_tokens": cache, "output_tokens": output, "reasoning_output_tokens": reasoning, "total_tokens": input + output]
}
private func count(_ total: [String: Any]? = nil, last: [String: Any]? = nil, at: String = "2026-10-13T09:02:00Z") -> [String: Any] {
    var info: [String: Any] = [:]
    if let total { info["total_token_usage"] = total }
    if let last { info["last_token_usage"] = last }
    return ["type": "event_msg", "timestamp": at, "payload": ["type": "token_count", "info": info]]
}
private func request(_ response: String, _ tokens: [String: Any], total: [String: Any]? = nil,
                     owner: String = "session", model: String? = nil, at: String = "2026-10-13T09:01:59Z") -> [String: Any] {
    var p: [String: Any] = ["response_id": response, "thread_id": owner, "turn_id": "turn-A", "usage": tokens]
    if let total { p["thread_token_usage"] = total }
    if let model { p["model"] = model }
    return ["type": "token_usage_record", "timestamp": at, "payload": p]
}
private func compact(_ id: String) -> [String: Any] {
    ["type": "compacted", "timestamp": "2026-10-13T09:02:01Z", "payload": ["compaction_response_id": id]]
}

@Test func hourlyTotalsMatchDeduplicatedDailyUsage() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), at: "2026-10-13T00:05:00Z"),
        count(usage(200, 20), at: "2026-10-13T00:59:00Z"),
        count(usage(200, 20), at: "2026-10-13T00:59:01Z"),
        count(usage(300, 30), at: "2026-10-13T01:00:00Z")])
    let report = try logs.scan()
    let day = try #require(ISO8601DateFormatter().date(from: "2026-10-13T12:00:00Z"))
    let hours = report.hourlyTotals(on: day, timeZone: TimeZone(secondsFromGMT: 0)!)
    #expect(hours.count == 24)
    #expect(hours[0].usage.total == 220)
    #expect(hours[1].usage.total == 110)
    #expect(hours[2].usage.isZero)
    #expect(hours.reduce(TokenUsage()) { $0 + $1.usage } == report.totals(in: .all))
}

@Test func hourlyBucketsRespectLocalMidnight() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), at: "2026-10-13T15:59:00Z"),
        count(usage(200, 20), at: "2026-10-13T16:01:00Z")])
    let zone = TimeZone(identifier: "Asia/Shanghai")!
    let report = try logs.scan(CodexLogScanner(timeZone: zone))
    let before = try #require(ISO8601DateFormatter().date(from: "2026-10-13T15:59:00Z"))
    let after = try #require(ISO8601DateFormatter().date(from: "2026-10-13T16:01:00Z"))
    #expect(report.hourlyTotals(on: before, timeZone: zone)[23].usage.total == 110)
    #expect(report.hourlyTotals(on: after, timeZone: zone)[0].usage.total == 110)
}

@Test func hourlyBucketsKeepRepeatedDSTHoursDistinct() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), at: "2026-11-01T05:30:00Z"),
        count(usage(200, 20), at: "2026-11-01T06:30:00Z")])
    let zone = TimeZone(identifier: "America/New_York")!
    let report = try logs.scan(CodexLogScanner(timeZone: zone))
    let day = try #require(ISO8601DateFormatter().date(from: "2026-11-01T12:00:00Z"))
    let hours = report.hourlyTotals(on: day, timeZone: zone)
    #expect(hours.count == 25)
    #expect(Set(hours.map(\.hour)).count == 25)
    #expect(hours.filter { !$0.usage.isZero }.map { $0.usage.total } == [110, 110])
    let spring = try #require(ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z"))
    #expect(ScanReport.empty.hourlyTotals(on: spring, timeZone: zone).count == 23)
}

@Test func singleModelAndSubsetCounters() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(1000, 100, cache: 800, reasoning: 40))])
    let report = try logs.scan()
    #expect(report.totals(in: .all) == TokenUsage(input: 1000, cachedInput: 800, output: 100, reasoning: 40))
    #expect(report.totals(in: .all).total == 1100)
    #expect(report.totals(in: .all).uncachedInput == 200)
    #expect(report.models(in: .all)[0].sessionCount == 1)
}
@Test func repeatedSnapshotsAndModelSwitch() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100, 10)), count(usage(100, 10)), count(usage(250, 30)),
                    turn("model-B", id: "turn-B"), count(usage(400, 50), last: usage(150, 20))])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 450)
    #expect(report.models(in: .all).first { $0.model == "model-A" }?.usage.total == 280)
    #expect(report.models(in: .all).first { $0.model == "model-B" }?.usage.total == 170)
}
@Test func unknownModelIsNeverBackfilled() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), count(usage(120, 20)), turn("declared-later"), count(usage(180, 25), last: usage(60, 5))])
    let models = try logs.scan().models(in: .all)
    #expect(models.first { $0.model == "Unknown model" }?.usage.total == 140)
    #expect(models.first { $0.model == "declared-later" }?.usage.total == 65)
}
@Test func missingContextModelClearsPriorModel() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), turn(nil, id: "turn-B"), count(usage(200, 20), last: usage(100))])
    #expect(try logs.scan().models(in: .all).first { $0.model == "Unknown model" }?.usage.total == 110)
}
@Test func archiveIdentityDuplicatesCountOnce() throws {
    let logs = try Logs(); defer { logs.remove() }
    let rows = [meta(), turn(), count(usage(100))]
    try logs.write(rows, name: "active.jsonl")
    try logs.write(rows, name: "different-name.jsonl", archived: true)
    let report = try logs.scan()
    #expect(report.sessions.count == 1)
    #expect(report.fileCount == 2)
    #expect(report.totals(in: .all).total == 110)
}
@Test func equalBasenamesWithDifferentSessionsAreRetained() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("one"), turn(), count(usage(100))], name: "one/same.jsonl")
    try logs.write([meta("two"), turn(), count(usage(200))], name: "two/same.jsonl")
    #expect(try logs.scan().sessions.count == 2)
    #expect(try logs.scan().totals(in: .all).total == 320)
}
@Test func longerArchiveIsNotDiscarded() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100))])
    try logs.write([meta(), turn(), count(usage(100)), count(usage(200, 20))], archived: true)
    #expect(try logs.scan().totals(in: .all).total == 220)
    #expect(try logs.scan().diagnostics.contains { $0.kind == .supersededCopy && $0.severity == .information })
}
@Test func counterResetUsesLastRequest() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(1000, 100)), count(usage(500, 50), last: usage(50, 5)),
                    count(usage(600, 60), last: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 1265)
    #expect(try logs.scan().warnings.contains { $0.contains("回退") })
}
@Test func resetWithoutLastIsNotInvented() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(1000, 100)), count(usage(500, 50)), count(usage(600, 60))])
    #expect(try logs.scan().totals(in: .all).total == 1210)
}
@Test func initialUnobservedHistoryIsExcluded() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(1000, 100), last: usage(50, 5)), count(usage(1100, 110), last: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 165)
    #expect(try logs.scan().warnings.contains { $0.contains("未观察") })
}
@Test func lastOnlyDuplicatesAreConservative() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(last: usage(100)), count(last: usage(100), at: "2026-10-13T09:02:03Z"),
                    turn("model-A", id: "turn-B"), count(last: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 220)
    #expect(try logs.scan().warnings.contains { $0.contains("保守去重") })
}
@Test func damagedAndPartialLinesRecoverOnAppend() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100))])
    let url = logs.root.appendingPathComponent("sessions/rollout.jsonl")
    let row = try JSONSerialization.data(withJSONObject: count(usage(200, 20)))
    var data = try Data(contentsOf: url); data.append(Data("not-json\n".utf8)); data.append(row.prefix(row.count / 2)); try data.write(to: url)
    let scanner = CodexLogScanner()
    let first = try logs.scan(scanner)
    #expect(first.invalidLineCount == 1)
    #expect(first.totals(in: .all).total == 110)
    data.append(row.suffix(row.count - row.count / 2)); data.append(10); try data.write(to: url)
    let next = try logs.scan(scanner)
    #expect(next.totals(in: .all).total == 220)
    #expect(next.invalidLineCount == 1)
}
@Test func missingRequiredAndIllegalFieldsAreVisible() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(["input_tokens": 99]), count(["input_tokens": true, "output_tokens": 10]),
                    count(usage(100, cache: 200)), count(["input_tokens": -1, "output_tokens": 0]), count(usage(10, 1))])
    #expect(try logs.scan().totals(in: .all).total == 11)
    #expect(try logs.scan().warnings.contains { $0.contains("非法") })
}
@Test func crossDayDeltasUseEventDate() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), at: "2026-10-13T23:59:59Z"),
                    count(usage(250, 30), last: usage(150, 20), at: "2026-10-14T00:00:01Z")])
    let slices = try logs.scan().dailyTotals(in: .all)
    #expect(slices.map(\.day) == ["2026-10-13", "2026-10-14"])
    #expect(slices.map { $0.usage.total } == [110, 170])
    let now = ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z")!
    #expect(UsagePeriod.today.includes(day: "2026-10-14", now: now))
    #expect(!UsagePeriod.today.includes(day: "2026-10-13", now: now))
    #expect(UsagePeriod.sevenDays.includes(day: "2026-10-08", now: now))
    #expect(!UsagePeriod.sevenDays.includes(day: "2026-10-07", now: now))
    #expect(!UsagePeriod.thirtyDays.includes(day: "2026-10-15", now: now))
}
@Test func localTimezoneMidnightIsCorrect() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), at: "2026-10-13T16:00:00Z")])
    let scanner = CodexLogScanner(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
    #expect(try logs.scan(scanner).dailyTotals(in: .all)[0].day == "2026-10-14")
}
@Test func unchangedCacheAppendAndDeletion() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100))])
    let scanner = CodexLogScanner()
    #expect(try logs.scan(scanner).cachedFileCount == 0)
    #expect(try logs.scan(scanner).cachedFileCount == 1)
    try logs.write([meta(), turn(), count(usage(100)), count(usage(200, 20))])
    #expect(try logs.scan(scanner).totals(in: .all).total == 220)
    try FileManager.default.removeItem(at: logs.root.appendingPathComponent("sessions/rollout.jsonl"))
    #expect(try logs.scan(scanner).totals(in: .all).isZero)
}
@Test func inheritedPrefixAndResetAreCountedOnce() throws {
    let logs = try Logs(); defer { logs.remove() }
    let prefix = [turn(), count(usage(100)), count(usage(200, 20))]
    try logs.write([meta("parent")] + prefix, name: "parent.jsonl")
    try logs.write([meta("child", parent: "parent")] + prefix + [count(usage(50, 5), last: usage(50, 5))], name: "child.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 275)
    #expect(report.sessions.first { $0.id == "child" }?.replayDeduplicated == true)
}
@Test func sameCounterWithDifferentTimestampIsNotReplayProof() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("parent"), turn(), count(usage(100))], name: "parent.jsonl")
    try logs.write([meta("child", parent: "parent"), turn(), count(usage(100), last: usage(100), at: "2026-10-13T09:03:00Z")], name: "child.jsonl")
    let child = try #require(logs.scan().sessions.first { $0.id == "child" })
    #expect(child.usage(in: .all).total == 110)
    #expect(child.replayUnverified)
}
@Test func requestIdentitySuppressesSnapshotsAndDuplicateRecords() throws {
    let logs = try Logs(); defer { logs.remove() }
    let tokens = usage(100, 10, cache: 80, reasoning: 4)
    let record = request("resp-one", tokens, total: tokens)
    try logs.write([meta(), turn(), record, count(tokens, last: tokens), record, count(tokens, last: tokens)])
    #expect(try logs.scan().totals(in: .all).total == 110)
}
@Test func requestAfterSnapshotIsNotCountedTwice() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), request("resp-one", usage(100), total: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 110)
}
@Test func foreignRequestHistoryIsExcluded() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("child", parent: "absent"), turn(), request("parent-request", usage(100), owner: "absent"),
                    request("own-request", usage(50, 5), total: usage(50, 5), owner: "child"), count(usage(50, 5))])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 55)
    #expect(report.sessions[0].replayDeduplicated)
}
@Test func remoteCompactionIsAddedOnceWithoutChangingBaseline() throws {
    let logs = try Logs(); defer { logs.remove() }
    let record = request("compact-one", usage(30, 3), total: usage(100), model: "compactor")
    try logs.write([meta(), turn(), count(usage(100)), record, compact("compact-one"), record,
                    count(usage(200, 20), last: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 253)
    #expect(try logs.scan().models(in: .all).first { $0.model == "compactor" }?.usage.total == 33)
}
@Test func localCompactionSnapshotIsNotAddedTwice() throws {
    let logs = try Logs(); defer { logs.remove() }
    let record = request("compact-one", usage(30, 3), total: usage(130, 13))
    try logs.write([meta(), turn(), count(usage(100)), record, count(usage(130, 13), last: usage(30, 3)), compact("compact-one")])
    #expect(try logs.scan().totals(in: .all).total == 143)
    #expect(try logs.scan().models(in: .all).first { $0.model == "Unknown model" }?.usage.total == 33)
}
@Test func missingTimestampIsNotFileModificationDate() throws {
    let logs = try Logs(); defer { logs.remove() }
    var row = count(usage(100)); row.removeValue(forKey: "timestamp")
    try logs.write([meta(), turn(), row])
    #expect(try logs.scan().totals(in: .all).isZero)
    #expect(try logs.scan().warnings.contains { $0.contains("时间") })
}
@Test func sessionsWithoutUsageRemainVisible() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn()])
    #expect(try logs.scan().recentSessions(in: .all).count == 1)
}
@Test func execFallbackDoesNotDoubleCountRolloutUsage() throws {
    let logs = try Logs(); defer { logs.remove() }
    let exec: [String: Any] = ["type": "turn.completed", "timestamp": "2026-10-13T09:03:00Z", "usage": usage(100)]
    try logs.write([meta(), turn(), exec])
    #expect(try logs.scan().totals(in: .all).total == 110)
    try logs.write([meta(), turn(), count(usage(100)), exec])
    #expect(try logs.scan().totals(in: .all).total == 110)
}
@Test func archivedOnlyHomeAndMultipleRoots() throws {
    let logs = try Logs(); defer { logs.remove() }
    try FileManager.default.removeItem(at: logs.root.appendingPathComponent("sessions"))
    try logs.write([meta(), turn(), count(usage(100))], archived: true)
    #expect(try logs.scan().totals(in: .all).total == 110)
    #expect(try CodexLogScanner().scan(homePath: logs.root.path + "," + logs.root.path).fileCount == 1)
}
@Test func checkedInFixtureIsReproducible() throws {
    let logs = try Logs(); defer { logs.remove() }
    let fixture = try #require(Bundle.module.url(forResource: "switch-model", withExtension: "jsonl", subdirectory: "Fixtures"))
    try FileManager.default.copyItem(at: fixture, to: logs.root.appendingPathComponent("sessions/fixture.jsonl"))
    #expect(try logs.scan().totals(in: .all) == TokenUsage(input: 250, cachedInput: 180, output: 30, reasoning: 15))
    #expect(try logs.scan().models(in: .all).count == 2)
}
@Test func distinctThreadAndContextCountersAfterCompactionDoNotDoubleCount() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(1000, 100)),
                    request("compaction", usage(200, 20), total: usage(1200, 120)), compact("compaction"),
                    count(usage(1000, 100), last: usage(0, 0)),
                    request("next-response", usage(50, 5), total: usage(1250, 125)),
                    count(usage(1050, 105), last: usage(50, 5))])
    #expect(try logs.scan().totals(in: .all).total == 1375)
}
@Test func localCompactionNotificationBeforeRecordDoesNotDoubleCount() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), count(usage(130, 13), last: usage(30, 3)),
                    request("compact-first", usage(30, 3), total: usage(130, 13)), compact("compact-first")])
    #expect(try logs.scan().totals(in: .all).total == 143)
}
@Test func nonconsecutiveOldSnapshotsDoNotReplayUsage() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), count(usage(200, 20)), count(usage(100), last: usage(100)), count(usage(250, 25))])
    #expect(try logs.scan().totals(in: .all).total == 275)
    #expect(try logs.scan().warnings.contains { $0.contains("旧累计快照") })
}
@Test func notificationFirstThenLegacyCounterKeepsBaseline() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100), last: usage(100)), request("after-notification", usage(100), total: usage(100)),
                    count(usage(150, 15), last: usage(50, 5))])
    #expect(try logs.scan().totals(in: .all).total == 165)
}
@Test func symbolicLinksAreNotReadAsLogs() throws {
    let logs = try Logs(); defer { logs.remove() }
    let target = logs.root.appendingPathComponent("auth.json")
    try Data("not-a-log".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(at: logs.root.appendingPathComponent("sessions/auth.jsonl"), withDestinationURL: target)
    #expect(try logs.scan().fileCount == 0)
}
@Test func emptyRootIsAnError() throws {
    #expect(throws: CodexLogScanner.ScannerError.self) { try CodexLogScanner().scan(homePath: " , ") }
}
@Test func missingSubsetFieldsAreUnknownInsteadOfZero() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(["input_tokens": 100, "output_tokens": 10])])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 110)
    #expect(!report.totals(in: .all).cachedInputKnown)
    #expect(!report.totals(in: .all).reasoningKnown)
    #expect(report.warnings.contains { $0.contains("未完整记录") })
}
@Test func duplicateRequestRecordDoesNotConsumeANewEqualSizedRequest() throws {
    let logs = try Logs(); defer { logs.remove() }
    let record = request("same-response", usage(100), total: usage(100))
    try logs.write([meta(), turn(), record, count(usage(100), last: usage(100)), record, count(usage(200, 20), last: usage(100))])
    #expect(try logs.scan().totals(in: .all).total == 220)
}
@Test func corruptHugeCountersCannotOverflowAggregation() throws {
    let logs = try Logs(); defer { logs.remove() }
    let huge = usage(4_000_000_000_000_000_000, 0)
    try logs.write([meta(), turn(), request("huge-one", huge), request("huge-two", huge), request("huge-three", huge)])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 8_000_000_000_000_000_000)
    #expect(report.warnings.contains { $0.contains("Int64") })
}
@Test func unnotifiedRequestThenLegacyUsageIsNotSubtractedTwice() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), request("unnotified", usage(100), total: usage(100)), count(usage(180, 18), last: usage(80, 8))])
    #expect(try logs.scan().totals(in: .all).total == 198)
}

@Test func physicalGenerationsRetainIndependentNativeExpenditure() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), request("old", usage(100), model: "model-A")], name: "old.jsonl")
    try logs.write([meta(), turn("model-B"), request("new", usage(200, 20), model: "model-B", at: "2026-10-14T09:01:59Z")], name: "new.jsonl")
    let report = try logs.scan()
    #expect(report.sessions.count == 1)
    #expect(report.totals(in: .all).total == 330)
    #expect(Set(report.records(in: .all).compactMap(\.requestID)) == ["old", "new"])
    #expect(report.models(in: .all).count == 2)
    #expect(report.dailyTotals(in: .all).count == 2)
}

@Test func conflictingNativeResponseIsNotArbitrarilySelected() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), request("same", usage(100)), request("good", usage(40))], name: "one.jsonl")
    try logs.write([meta(), turn(), request("same", usage(200))], name: "two.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 50)
    #expect(report.diagnostics.contains { $0.kind == .conflictingResponse && $0.severity == .warning })
}

@Test func responseConflictChecksAttributionNotJustTotal() throws {
    for field in ["model", "turn_id", "thread_id", "timestamp"] {
        let logs = try Logs(); defer { logs.remove() }
        let original = request("same", usage(100))
        var changed = original
        if field == "timestamp" { changed[field] = "2026-10-14T09:01:59Z" }
        else {
            var payload = changed["payload"] as! [String: Any]
            payload[field] = "different"
            changed["payload"] = payload
        }
        // A foreign inherited row cannot invalidate its owner's record; only genuinely
        // owned records are compared. Two different genuine owners conflict globally.
        let otherMeta = field == "thread_id" ? meta("different") : meta()
        try logs.write([meta(), turn(), original], name: "one.jsonl")
        try logs.write([otherMeta, turn(), changed], name: "two.jsonl")
        #expect(try logs.scan().diagnostics.contains { $0.kind == .conflictingResponse })
    }
}

@Test func exactNativeCopyIsInformationRatherThanWarning() throws {
    let logs = try Logs(); defer { logs.remove() }
    let rows = [meta(), turn(), request("same", usage(100))]
    try logs.write(rows)
    try logs.write(rows, name: "copy.jsonl", archived: true)
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 110)
    #expect(report.warnings.isEmpty)
    #expect(report.diagnostics.contains { $0.kind == .supersededCopy && $0.severity == .information })
}

@Test func divergentLegacyStreamsAreNotSummed() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100))], name: "one.jsonl")
    try logs.write([meta(), turn(), count(usage(200))], name: "two.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 110)
    #expect(report.diagnostics.contains { $0.kind == .divergentAccountingCopies && $0.severity == .warning })
}

private func historyMeta(_ target: String, ordinal: Int, offset: Int) -> [String: Any] {
    var value = meta()
    var payload = value["payload"] as! [String: Any]
    payload["history_base"] = ["thread_id": target, "end_ordinal_exclusive": ordinal, "end_byte_offset": offset]
    value["payload"] = payload
    return value
}
private func byteCount(_ lines: [[String: Any]]) throws -> Int {
    try lines.reduce(0) { try $0 + JSONSerialization.data(withJSONObject: $1, options: [.sortedKeys]).count + 1 }
}
@Test func validPhysicalHistoryReferenceIsResolvedLocally() throws {
    let logs = try Logs(); defer { logs.remove() }
    let physical = "11111111-1111-4111-8111-111111111111"
    var first = meta(); first["ordinal"] = 0
    var second = request("old", usage(100)); second["ordinal"] = 1
    let prefix = [first, second]
    try logs.write(prefix, name: "rollout-2026-10-13T09-00-00-\(physical).jsonl")
    try logs.write([historyMeta(physical, ordinal: 2, offset: try byteCount(prefix)), turn(), request("new", usage(200))], name: "suffix.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 320)
    #expect(report.diagnostics.contains { $0.kind == .historyReference && $0.severity == .information })
    #expect(!report.diagnostics.contains { $0.kind == .unresolvedHistoryReference })
}
@Test func missingAndInvalidHistoryBoundariesRemainWarnings() throws {
    let physical = "11111111-1111-4111-8111-111111111111"
    for boundary in ["missing", "ordinal", "byte", "middle"] {
        let logs = try Logs(); defer { logs.remove() }
        var first = meta(); first["ordinal"] = 0
        let offset = try byteCount([first])
        if boundary != "missing" { try logs.write([first], name: "rollout-2026-10-13T09-00-00-\(physical).jsonl") }
        try logs.write([historyMeta(physical, ordinal: boundary == "ordinal" ? 3 : 1,
            offset: boundary == "byte" ? offset + 99 : boundary == "middle" ? offset - 3 : offset), request("new", usage(20))], name: "suffix.jsonl")
        let report = try logs.scan()
        #expect(report.totals(in: .all).total == 30)
        #expect(report.diagnostics.contains { $0.kind == .unresolvedHistoryReference && $0.severity == .warning })
    }
}

@Test func physicalNativeSnapshotsNeverCrossDifferenceOrDoubleNotifications() throws {
    let logs = try Logs(); defer { logs.remove() }
    let first = usage(100, 10), second = usage(50, 5)
    try logs.write([meta(), turn(), request("old", first, total: first), count(first, last: first)], name: "old.jsonl")
    try logs.write([meta(), turn("model-B"), request("new", second, total: usage(200, 20), model: "model-B"),
        count(usage(300, 30), last: second), compact("new")], name: "new.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 165)
    #expect(report.records(in: .all).count == 2)
    #expect(report.models(in: .all).first { $0.model == "model-B" }?.usage.total == 55)
    #expect(!report.diagnostics.contains { $0.kind == .divergentAccountingCopies })
}
@Test func mixedLegacyAndNativeCopiesExposeUnprovableOverlap() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), count(usage(100)), count(usage(200, 20))], name: "legacy.jsonl")
    try logs.write([meta(), turn(), request("native", usage(100))], name: "native.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 220)
    #expect(report.diagnostics.contains { $0.kind == .divergentAccountingCopies })
}
@Test func emptyOrDamagedCopyDoesNotProveAncestor() throws {
    for damaged in [false, true] {
        let logs = try Logs(); defer { logs.remove() }
        try logs.write([meta()], name: "empty.jsonl")
        if damaged {
            let handle = try FileHandle(forWritingTo: logs.root.appendingPathComponent("sessions/empty.jsonl"))
            try handle.seekToEnd(); try handle.write(contentsOf: Data("broken\n".utf8)); try handle.close()
        }
        try logs.write([meta(), turn(), request("valid", usage(100))], name: "valid.jsonl")
        let report = try logs.scan()
        #expect(report.totals(in: .all).total == 110)
        #expect(!report.diagnostics.contains { $0.kind == .supersededCopy })
        #expect(report.diagnostics.contains { $0.kind == .divergentAccountingCopies })
    }
}
@Test func physicalFilenameUsesImmutableSuffixNotStableThreadUUID() throws {
    let logs = try Logs(); defer { logs.remove() }
    let stable = "22222222-2222-4222-8222-222222222222"
    let physical = "11111111-1111-4111-8111-111111111111"
    var row = meta(); row["ordinal"] = 40
    try logs.write([row], name: "rollout-2026-10-13T09-00-00-\(stable)_\(physical).jsonl")
    try logs.write([historyMeta(physical, ordinal: 41, offset: try byteCount([row])), request("new", usage(100))], name: "suffix.jsonl")
    #expect(!(try logs.scan()).diagnostics.contains { $0.kind == .unresolvedHistoryReference })
}
@Test func circularPhysicalHistoryIsNotClaimedComplete() throws {
    let logs = try Logs(); defer { logs.remove() }
    let a = "11111111-1111-4111-8111-111111111111", b = "22222222-2222-4222-8222-222222222222"
    var offset = 1
    var first: [String: Any] = [:], second: [String: Any] = [:]
    // Match both declared ordinal/byte boundaries before detecting graph cycles.
    for _ in 0..<10 {
        first = historyMeta(b, ordinal: 1, offset: offset); first["ordinal"] = 0
        second = historyMeta(a, ordinal: 1, offset: offset); second["ordinal"] = 0
        let length = try byteCount([first])
        if length == offset { break }
        offset = length
    }
    #expect(try byteCount([first]) == offset)
    #expect(try byteCount([second]) == offset)
    try logs.write([first, request("a", usage(100))], name: "rollout-2026-10-13T09-00-00-\(a).jsonl")
    try logs.write([second, request("b", usage(200))], name: "rollout-2026-10-13T09-00-00-\(b).jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 320)
    #expect(report.diagnostics.filter { $0.kind == .unresolvedHistoryReference }.count == 2)
}
@Test func emptyReferencedPrefixDoesNotTraverseTargetAncestry() throws {
    let logs = try Logs(); defer { logs.remove() }
    let physical = "11111111-1111-4111-8111-111111111111"
    try logs.write([historyMeta(physical, ordinal: 0, offset: 0), request("new", usage(100))],
        name: "rollout-2026-10-13T09-00-00-\(physical).jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 110)
    #expect(!report.diagnostics.contains { $0.kind == .unresolvedHistoryReference })
}
@Test func corruptSuffixDoesNotInvalidateValidReferencedPrefix() throws {
    let logs = try Logs(); defer { logs.remove() }
    let physical = "11111111-1111-4111-8111-111111111111"
    let name = "rollout-2026-10-13T09-00-00-\(physical).jsonl"
    var first = meta(); first["ordinal"] = 0
    let offset = try byteCount([first])
    try logs.write([first], name: name)
    let handle = try FileHandle(forWritingTo: logs.root.appendingPathComponent("sessions").appendingPathComponent(name))
    try handle.seekToEnd(); try handle.write(contentsOf: Data("broken\n".utf8)); try handle.close()
    try logs.write([historyMeta(physical, ordinal: 1, offset: offset), request("new", usage(100))], name: "suffix.jsonl")
    let report = try logs.scan()
    #expect(!report.diagnostics.contains { $0.kind == .unresolvedHistoryReference })
    #expect(report.diagnostics.contains { $0.kind == .invalidJSON })
}
@Test func missingNativeOwnerIsNeverInferredFromContainingSession() throws {
    for missing in [true, false] {
        let logs = try Logs(); defer { logs.remove() }
        let tokens = usage(100)
        var native = request("ambiguous", tokens, total: tokens)
        var payload = native["payload"] as! [String: Any]
        if missing { payload.removeValue(forKey: "thread_id") } else { payload["thread_id"] = " " }
        native["payload"] = payload
        try logs.write([meta(), turn(), native, count(tokens, last: tokens)])
        let report = try logs.scan()
        #expect(report.totals(in: .all).total == 0)
        #expect(report.records(in: .all).isEmpty)
        #expect(report.diagnostics.contains { $0.kind == .missingIdentity })
    }
}
@Test func foreignNativeNotificationDoesNotBecomeChildLegacyUsage() throws {
    let logs = try Logs(); defer { logs.remove() }
    let inherited = usage(100), own = usage(40, 4)
    try logs.write([meta("child", parent: "missing-parent"), turn(), request("foreign", inherited, owner: "parent"),
        count(inherited, last: inherited), request("own", own, owner: "child"), count(usage(140, 14), last: own)])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 44)
    #expect(report.records(in: .all).compactMap(\.requestID) == ["own"])
}
@Test func ambiguousNativeOwnerCannotReappearViaUnpairedCounter() throws {
    let logs = try Logs(); defer { logs.remove() }
    var native = request("ambiguous", usage(100), total: usage(100))
    var payload = native["payload"] as! [String: Any]; payload.removeValue(forKey: "thread_id"); native["payload"] = payload
    // Counter and last components differ from the request, so adjacent pairing cannot
    // prove which part belongs to an owned request. Do not resurrect the ambiguity.
    try logs.write([meta(), turn(), native, count(usage(200, 20), last: usage(200, 20)),
        request("own", usage(40, 4)), count(usage(240, 24), last: usage(40, 4))])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 44)
    #expect(report.diagnostics.contains { $0.kind == .counterAmbiguity })
}
@Test func malformedForeignNativeIdentityRetainsOwnershipProvenance() throws {
    for missingOwner in [true, false] {
        let logs = try Logs(); defer { logs.remove() }
        let tokens = usage(100)
        var native = request("foreign", tokens, total: tokens, owner: "parent")
        var payload = native["payload"] as! [String: Any]
        payload.removeValue(forKey: "response_id")
        if missingOwner { payload.removeValue(forKey: "thread_id") }
        native["payload"] = payload
        try logs.write([meta("child"), turn(), native, count(tokens, last: tokens),
            request("owned", usage(40, 4), owner: "child"), count(usage(140, 14), last: usage(40, 4))])
        let report = try logs.scan()
        #expect(report.totals(in: .all).total == 44)
        #expect(report.diagnostics.contains { $0.kind == .missingIdentity })
    }
}
@Test func malformedOwnedIdentityDoesNotEraseIndependentValidLegacyCounter() throws {
    let logs = try Logs(); defer { logs.remove() }
    var native = request("owned", usage(100), total: usage(100))
    var payload = native["payload"] as! [String: Any]; payload.removeValue(forKey: "response_id"); native["payload"] = payload
    try logs.write([meta(), turn(), native, count(usage(100), last: usage(100))])
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 110)
    #expect(report.records(in: .all).first?.evidence == .lastUsage)
    #expect(report.records(in: .all).first?.requestID == nil)
    #expect(report.diagnostics.contains { $0.kind == .missingIdentity })
}

@Test func globalResponseConflictDiagnosesEveryAffectedSource() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("first-owner"), turn(), request("conflict", usage(100), owner: "first-owner")], name: "a.jsonl")
    try logs.write([meta("second-owner"), turn(), request("conflict", usage(100), owner: "second-owner")], name: "b.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 0)
    let conflicts = report.diagnostics.filter { $0.kind == .conflictingResponse }
    #expect(Set(conflicts.compactMap(\.sessionID)) == ["first-owner", "second-owner"])
    #expect(Set(conflicts.compactMap(\.fileName)) == ["a.jsonl", "b.jsonl"])
}

@Test func laterCompactionMarkerNormalizesRetainedPrefixCopies() throws {
    for explicitModel in [nil, "compaction-model"] as [String?] {
        let logs = try Logs(); defer { logs.remove() }
        let record = request("compact-prefix", usage(100), model: explicitModel)
        let prefix = [meta(), turn(), record]
        try logs.write(prefix + [compact("compact-prefix")], name: "active.jsonl")
        try logs.write(prefix, name: "prefix.jsonl", archived: true)
        let report = try logs.scan()
        #expect(report.totals(in: .all).total == 110)
        let row = try #require(report.records(in: .all).first)
        #expect(row.isCompaction)
        #expect(row.model == (explicitModel ?? "Unknown model"))
        #expect(!report.diagnostics.contains { $0.kind == .conflictingResponse })
        #expect(report.diagnostics.contains { $0.kind == .supersededCopy })
    }
}

@Test func compactionCopiesUseUnambiguousExplicitModelButRejectContradictions() throws {
    for conflictingModels in [false, true] {
        let logs = try Logs(); defer { logs.remove() }
        try logs.write([meta(), turn(), request("compact-model", usage(100), model: "confirmed-model"), compact("compact-model")], name: "a.jsonl")
        try logs.write([meta(), turn("context-model"), request("compact-model", usage(100), model: conflictingModels ? "contradictory-model" : nil)], name: "b.jsonl", archived: true)
        let report = try logs.scan()
        if conflictingModels {
            #expect(report.totals(in: .all).total == 0)
            #expect(report.diagnostics.filter { $0.kind == .conflictingResponse }.count == 2)
        } else {
            #expect(report.totals(in: .all).total == 110)
            #expect(report.records(in: .all).first?.model == "confirmed-model")
            #expect(report.records(in: .all).first?.isCompaction == true)
            #expect(!report.diagnostics.contains { $0.kind == .conflictingResponse })
        }
    }
}

@Test func legacyReplayMatchesEquivalentMillisecondTimestampForms() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("parent"), turn(), count(usage(100), at: "2026-10-13T09:02:00.123456Z")], name: "parent.jsonl")
    try logs.write([meta("child", parent: "parent"), turn(),
                    count(usage(100), at: "2026-10-13T17:02:00.123+08:00"),
                    count(usage(150, 15), last: usage(50, 5), at: "2026-10-14T00:00:00.12Z")], name: "child.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 165)
    let child = try #require(report.sessions.first { $0.id == "child" })
    #expect(child.replayDeduplicated)
    #expect(child.records.count == 1)
    #expect(child.records[0].day == "2026-10-14")
}

@Test func canonicalFractionalTimestampsPreserveOrderingAndDayBuckets() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(),
                    request("before-midnight", usage(100), at: "2026-10-13T23:59:59.999999Z"),
                    request("at-midnight", usage(200), at: "2026-10-14T08:00:00.000+08:00"),
                    request("after-midnight", usage(300), at: "2026-10-14T00:00:00.1Z")])
    let report = try logs.scan()
    #expect(report.records(in: .all).map(\.requestID) == ["after-midnight", "at-midnight", "before-midnight"])
    #expect(report.dailyTotals(in: .all).map(\.usage.total) == [110, 520])
    let date = try #require(ISO8601DateFormatter().date(from: "2026-10-14T00:00:00Z"))
    #expect(report.hourlyTotals(on: date, timeZone: TimeZone(secondsFromGMT: 0)!)[0].usage.total == 520)
    #expect(report.records(in: .all, sortedByTime: false).count == report.records(in: .all).count)
}

@Test func cacheInvalidatesSameSizedRewriteAndRootChange() throws {
    let first = try Logs(); defer { first.remove() }
    let second = try Logs(); defer { second.remove() }
    try first.write([meta(), turn(), count(usage(100))])
    try second.write([meta("other"), turn(), count(usage(300))])
    let scanner = CodexLogScanner()
    #expect(try first.scan(scanner).totals(in: .all).total == 110)
    let file = first.root.appendingPathComponent("sessions/rollout.jsonl")
    let size = try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! NSNumber
    try first.write([meta(), turn(), count(usage(200))])
    try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(2)], ofItemAtPath: file.path)
    #expect((try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! NSNumber) == size)
    let rewritten = try first.scan(scanner)
    #expect(rewritten.cachedFileCount == 0 && rewritten.totals(in: .all).total == 210)
    #expect(try second.scan(scanner).totals(in: .all).total == 310)
    #expect(try first.scan(scanner).cachedFileCount == 0)
}

@Test func outOfRangeTimestampNeverAssignsConsumptionToNormalizedDay() throws {
    for raw in ["2026-10-14T25:00:00Z", "2026-10-14T00:60:00Z", "2026-10-14T00:00:60Z"] {
        let logs = try Logs(); defer { logs.remove() }
        try logs.write([meta(), turn(), request("invalid-clock", usage(100), at: raw)])
        let report = try logs.scan()
        #expect(report.totals(in: .all).isZero)
        #expect(report.records(in: .all).isEmpty)
        #expect(report.diagnostics.contains { $0.kind == .missingTimestamp })
    }
}


@Test func missingMetadataFilenameCannotAdmitNativeOrCompanionUsage() throws {
    for prior in [false, true] {
        for lastOnly in [false, true] {
            let logs = try Logs(); defer { logs.remove() }
            let tokens = usage(100, 20)
            let native = request("unverified", tokens, total: tokens, owner: "session")
            let notification = count(lastOnly ? nil : tokens, last: tokens)
            let lines = prior ? [turn(), notification, native] : [turn(), native, notification]
            // Before the fix this exact filename admitted the unverified request.
            try logs.write(lines, name: "session.jsonl")
            let report = try logs.scan()
            #expect(report.totals(in: .all).isZero)
            #expect(report.records(in: .all).isEmpty)
            #expect(report.sessions.first?.recordedSessionID == nil)
            #expect(report.diagnostics.contains { $0.kind == .missingIdentity })
        }
    }
}

@Test func unidentifiedCopyCannotPoisonVerifiedResponseOrCompaction() throws {
    let logs = try Logs(); defer { logs.remove() }
    let good = request("same-response", usage(100), total: usage(100), model: "model-A")
    try logs.write([meta(), turn(), good, count(usage(100), last: usage(100))], name: "good.jsonl")
    // More frames would previously select this file as primary; conflicting usage,
    // model and compaction evidence could invalidate the genuine response globally.
    try logs.write([turn(), request("same-response", usage(900), total: usage(900), model: "wrong"),
        count(usage(900), last: usage(900)), compact("same-response"),
        request("unverified-extra", usage(800), total: usage(1700)), count(usage(1700), last: usage(800))],
        name: "session.jsonl", archived: true)
    let report = try logs.scan()
    let verified = try #require(report.sessions.first { $0.recordedSessionID == "session" })
    #expect(report.totals(in: .all).total == 110)
    #expect(verified.records.count == 1)
    #expect(verified.records.first?.model == "model-A")
    #expect(verified.records.first?.isCompaction == false)
    #expect(!report.diagnostics.contains { $0.kind == .conflictingResponse })
}

@Test func unidentifiedLegacyFilenameDoesNotShareVerifiedSessionGroup() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta(), turn(), request("verified", usage(100))], name: "good.jsonl")
    try logs.write([turn(), count(usage(40, 4))], name: "session.jsonl")
    let report = try logs.scan()
    #expect(report.totals(in: .all).total == 154)
    #expect(report.sessions.count == 2)
    let recorded = try #require(report.sessions.first { $0.recordedSessionID != nil })
    #expect(recorded.id == "session")
    #expect(recorded.usage(in: .all).total == 110)
    #expect(report.sessions.first { $0.recordedSessionID == nil }?.usage(in: .all).total == 44)
}

@Test func metadataSessionIDAliasRemainsVerifiedIdentity() throws {
    let logs = try Logs(); defer { logs.remove() }
    var metadata = meta()
    var payload = metadata["payload"] as! [String: Any]
    payload.removeValue(forKey: "id"); payload["session_id"] = "session"
    metadata["payload"] = payload
    try logs.write([metadata, turn(), request("verified", usage(100))])
    let report = try logs.scan()
    #expect(report.sessions.first?.recordedSessionID == "session")
    #expect(report.totals(in: .all).total == 110)
}


@Test func unidentifiedLegacyArchiveCopiesRetainOneConservativeStream() throws {
    for prefix in [false, true] {
        let logs = try Logs(); defer { logs.remove() }
        let first = [turn(), count(usage(100), last: usage(100))]
        let full = first + [count(usage(140, 14), last: usage(40, 4))]
        try logs.write(full, name: "same.jsonl")
        try logs.write(prefix ? first : full, name: "same.jsonl", archived: true)
        let report = try logs.scan()
        #expect(report.sessions.count == 1)
        #expect(report.totals(in: .all).total == 154)
        #expect(report.records(in: .all).count == 2)
        #expect(report.sessions.first?.recordedSessionID == nil)
        #expect(report.diagnostics.contains { $0.kind == .supersededCopy })
    }
}

@Test func explicitSessionIDCannotCollideWithAllocatedUnknownInternalKey() throws {
    let logs = try Logs(); defer { logs.remove() }
    try logs.write([meta("unidentified:orphan"), turn(),
        request("real-one", usage(100), owner: "unidentified:orphan")], name: "good.jsonl")
    try logs.write([meta("unidentified:unidentified:orphan"), turn(),
        request("real-two", usage(20, 2), owner: "unidentified:unidentified:orphan")], name: "other.jsonl")
    let legacy = [turn(), count(usage(40, 4))]
    try logs.write(legacy, name: "orphan.jsonl")
    try logs.write(legacy, name: "orphan.jsonl", archived: true)
    let report = try logs.scan()
    #expect(report.sessions.count == 3)
    #expect(Set(report.sessions.map(\.id)).count == 3)
    #expect(report.totals(in: .all).total == 176)
    let unknown = try #require(report.sessions.first { $0.recordedSessionID == nil })
    #expect(unknown.id == "unidentified:unidentified:unidentified:orphan")
    #expect(unknown.usage(in: .all).total == 44)
    #expect(report.sessions.first { $0.id == "unidentified:orphan" }?.recordedSessionID == "unidentified:orphan")
}


@Test func generatedUnknownKeyCannotResolveDeclaredParentIdentity() throws {
    let logs = try Logs(); defer { logs.remove() }
    let first = count(usage(100), last: usage(100))
    try logs.write([turn(), first], name: "orphan.jsonl")
    try logs.write([meta("child", parent: "unidentified:orphan"), turn(), first,
        count(usage(140, 14), last: usage(40, 4))], name: "child.jsonl")
    let report = try logs.scan()
    let child = try #require(report.sessions.first { $0.recordedSessionID == "child" })
    #expect(child.usage(in: .all).total == 154)
    #expect(!child.replayDeduplicated)
    #expect(child.replayUnverified)
    #expect(report.totals(in: .all).total == 264)
    #expect(report.diagnostics.contains { $0.kind == .inheritedHistory && $0.sessionID == "child" })
}
