import Foundation
import Testing
@testable import CodexStatsCore

private struct TimingLogs {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    func write(_ lines: [[String: Any]], name: String = "turn.jsonl", archived: Bool = false, tail: String = "") throws {
        let folder = root.appendingPathComponent(archived ? "archived_sessions" : "sessions")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var data = Data()
        for line in lines { data.append(try JSONSerialization.data(withJSONObject: line)); data.append(10) }
        data.append(Data(tail.utf8))
        try data.write(to: folder.appendingPathComponent(name))
    }
    func scan() throws -> ScanReport { try CodexLogScanner(timeZone: TimeZone(secondsFromGMT: 0)!).scan(homePath: root.path) }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
private func timingMeta(history: Bool = false) -> [String: Any] {
    var p: [String: Any] = ["id": "owner", "cwd": "/example/project"]
    if history { p["history_base"] = ["thread_id": "absent", "end_ordinal_exclusive": 1, "end_byte_offset": 20] }
    return ["type": "session_meta", "timestamp": "2026-10-13T23:58:00Z", "payload": p]
}
private func timingEvent(_ type: String, at: String, fields: [String: Any] = [:]) -> [String: Any] {
    var p = fields; p["type"] = type; p["turn_id"] = "whole-turn"
    return ["type": "event_msg", "timestamp": at, "payload": p]
}
private let timingStart = timingEvent("task_started", at: "2026-10-13T23:59:00Z")
private func timingEnd(_ duration: Any = 120_000, first: Any = 2000, error: Bool = false) -> [String: Any] {
    var fields: [String: Any] = ["duration_ms": duration, "time_to_first_token_ms": first]
    if error { fields["error"] = ["message": "failure"] }
    return timingEvent("task_complete", at: "2026-10-14T00:01:00Z", fields: fields)
}
private func timingResponse(_ id: String, output: Int = 20, owner: String = "owner", at: String = "2026-10-14T00:00:00Z") -> [String: Any] {
    ["type": "token_usage_record", "timestamp": at, "payload": ["thread_id": owner, "turn_id": "whole-turn", "response_id": id,
        "usage": ["input_tokens": 100, "output_tokens": output, "cached_input_tokens": 80, "reasoning_output_tokens": 10]]]
}

@Test func completeTurnUsesWholeDeduplicatedOutputAcrossDateFilters() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    var a = timingResponse("a", output: 20, at: "2026-10-13T23:59:30Z")
    var aPayload = a["payload"] as! [String: Any]; aPayload["model"] = "model-A"; a["payload"] = aPayload
    var b = timingResponse("b", output: 40)
    var bPayload = b["payload"] as! [String: Any]; bPayload["model"] = "model-B"; b["payload"] = bPayload
    let lines = [timingMeta(), timingStart, a, a, b, timingEnd()]
    try logs.write(lines); try logs.write(lines, name: "copy.jsonl", archived: true)
    let report = try logs.scan()
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z"))
    let today = report.records(in: .today, now: now)
    #expect(today.count == 1)
    #expect(today[0].model == "model-B")
    let timing = try #require(today[0].turnPerformance)
    #expect(timing.durationMilliseconds == 120_000)
    #expect(timing.firstTokenMilliseconds == 2000)
    #expect(timing.outputTokens == 60)
    #expect(timing.responseCount == 2)
    #expect(timing.averageOutputTokensPerSecond == 0.5)
    #expect(report.totals(in: .all).output == 60)
    #expect(report.records(in: .all).allSatisfy { $0.turnPerformance == timing })
}

@Test(arguments: [0, -1, 1]) func invalidOrContradictoryTimingRemainsUnknown(duration: Int) throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(duration)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}
@Test func missingStartOrDurationCannotBorrowRequestOrItemLatency() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingResponse("a"), timingEnd()])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(NSNull())])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(true)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}
@Test func abortedAndFailedTurnsCannotShowSuccessfulPerformance() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEvent("turn_aborted", at: "2026-10-14T00:00:30Z"), timingEnd()])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(error: true)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}
@Test func additionalPhysicalResponsesInvalidateWholeTurnMean() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd()])
    try logs.write([timingMeta(), timingResponse("b")], name: "physical.jsonl")
    let rows = try logs.scan().records(in: .all)
    #expect(rows.count == 2)
    #expect(rows.allSatisfy { $0.turnPerformance?.durationMilliseconds == 120_000 })
    #expect(rows.allSatisfy { $0.turnPerformance?.averageOutputTokensPerSecond == nil })
}
@Test func incompleteInheritedOrCorruptHistoryCannotClaimCoveredMean() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(history: true), timingStart, timingResponse("a"), timingEnd()])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance?.outputTokens == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd()], tail: "{partial")
    #expect(try logs.scan().records(in: .all).first?.turnPerformance?.outputTokens == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd()], tail: "broken\n")
    #expect(try logs.scan().records(in: .all).first?.turnPerformance?.outputTokens == nil)
}
@Test func foreignOrMissingOwnerCannotContaminatePerformance() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingResponse("foreign", output: 100, owner: "elsewhere"), timingEnd()])
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.usage.output == 20)
    #expect(row.turnPerformance?.outputTokens == nil)
    try logs.write([timingMeta(), timingStart, timingResponse("foreign", owner: "elsewhere"), timingEnd()])
    #expect(try logs.scan().records(in: .all).isEmpty)
}
@Test func unresolvedLegacyUsageCannotAcquireTurnPerformance() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let legacy: [String: Any] = ["type": "event_msg", "timestamp": "2026-10-14T00:00:40Z", "payload": ["type": "token_count", "info": ["last_token_usage": ["input_tokens": 500, "output_tokens": 50]]]]
    try logs.write([timingMeta(), ["type": "turn_context", "payload": ["turn_id": "whole-turn"]], timingStart, timingResponse("a"), legacy, timingEnd()])
    let rows = try logs.scan().records(in: .all)
    #expect(rows.filter { $0.evidence != .responseRecord }.count == 1)
    #expect(rows.filter { $0.evidence != .responseRecord }.allSatisfy { $0.turnPerformance == nil })
    #expect(rows.first { $0.evidence == .responseRecord }?.turnPerformance?.outputTokens == nil)
}
@Test func conflictingCompleteTimersRemainUnknown() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd()])
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(100_000)], name: "copy.jsonl", archived: true)
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}

@Test func duplicateCompletionStatusAndTimersAreValidated() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let base = [timingMeta(), timingStart, timingResponse("a"), timingEnd()]
    try logs.write(base + [timingEnd()])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance?.outputTokens == 20)
    try logs.write(base + [timingEnd(100_000)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write(base + [timingEnd(first: 3000)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write(base + [timingEnd(error: true)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    try logs.write(base + [timingEvent("turn_aborted", at: "2026-10-14T00:01:01Z")])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}
@Test func recordedZeroTTFTIsDifferentFromMissing() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(first: 0)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance?.firstTokenMilliseconds == 0)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(first: NSNull())])
    let timing = try #require(try logs.scan().records(in: .all).first?.turnPerformance)
    #expect(timing.firstTokenMilliseconds == nil)
    #expect(timing.outputTokens == 20)
}
@Test func unattributedCumulativeFrameInsideTurnInvalidatesMean() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let counter = timingEvent("token_count", at: "2026-10-14T00:00:30Z", fields: ["info": ["total_token_usage": ["input_tokens": 500, "output_tokens": 100]]])
    try logs.write([timingMeta(), timingStart, timingResponse("a"), counter, timingEnd()])
    let native = try #require(try logs.scan().records(in: .all).first { $0.evidence == .responseRecord })
    #expect(native.turnPerformance?.outputTokens == nil)
}

@Test func inferredTurnCannotAcquirePerformanceMembership() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    var inferred = timingResponse("inferred")
    var payload = inferred["payload"] as! [String: Any]; payload.removeValue(forKey: "turn_id"); inferred["payload"] = payload
    try logs.write([timingMeta(), ["type": "turn_context", "payload": ["turn_id": "whole-turn"]], timingStart, timingResponse("a"), inferred, timingEnd()])
    let rows = try logs.scan().records(in: .all)
    #expect(rows.first { $0.requestID == "inferred" }?.turnPerformance == nil)
    #expect(rows.first { $0.requestID == "a" }?.turnPerformance?.outputTokens == nil)
}
@Test func abortedCopyInvalidatesOtherwiseCompleteTimer() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let lines = [timingMeta(), timingStart, timingResponse("a"), timingEnd()]
    try logs.write(lines)
    try logs.write(lines + [timingEvent("turn_aborted", at: "2026-10-14T00:01:01Z")], name: "copy.jsonl", archived: true)
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}

@Test(arguments: ["invalid", "true", "negative"]) func invalidDuplicateTTFTCannotEqualMissing(kind: String) throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let raw: Any = kind == "invalid" ? "not-a-number" : (kind == "true" ? true : -1)
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(first: NSNull()), timingEnd(first: raw)])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}

@Test func identitylessAbortDoesNotRetainSuccessfulTiming() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let abort: [String: Any] = ["type": "event_msg", "timestamp": "2026-10-14T00:01:01Z", "payload": ["type": "turn_aborted", "reason": "interrupted"]]
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd(), abort])
    #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
}
@Test func compactionResponseCopiesDoNotDuplicateTurnOutput() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let response = timingResponse("compaction", output: 40)
    let marker: [String: Any] = ["type": "compacted", "timestamp": "2026-10-14T00:00:10Z", "payload": ["compaction_response_id": "compaction"]]
    let lines = [timingMeta(), timingStart, response, response, marker, timingEnd()]
    try logs.write(lines); try logs.write(lines, name: "copy.jsonl", archived: true)
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.isCompaction)
    #expect(row.turnPerformance?.outputTokens == 40)
    #expect(row.turnPerformance?.responseCount == 1)
}

@Test func missingOwnerResponseInvalidatesMeanWithoutInventingMembership() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    var missing = timingResponse("missing")
    var payload = missing["payload"] as! [String: Any]; payload.removeValue(forKey: "thread_id"); missing["payload"] = payload
    try logs.write([timingMeta(), timingStart, timingResponse("a"), missing, timingEnd()])
    let rows = try logs.scan().records(in: .all)
    #expect(rows.count == 1)
    #expect(rows[0].requestID == "a")
    #expect(rows[0].turnPerformance?.outputTokens == nil)
}

@Test func invalidCompletionInPhysicalCopyInvalidatesOtherwiseCompleteTiming() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let valid = [timingMeta(), timingStart, timingResponse("a"), timingEnd()]
    try logs.write(valid)
    for end in [timingEnd(0), timingEnd(first: 200_000), timingEnd(first: "invalid")] {
        try logs.write([timingMeta(), timingStart, timingResponse("a"), end], name: "copy.jsonl", archived: true)
        #expect(try logs.scan().records(in: .all).first?.turnPerformance == nil)
    }
}

@Test func unidentifiedTurnResponseInPhysicalCopiesInvalidatesWholeTurnMean() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let valid = [timingMeta(), timingStart, timingResponse("a"), timingEnd()]
    try logs.write(valid)
    var unidentified = timingResponse("unidentified", output: 100)
    var payload = unidentified["payload"] as! [String: Any]
    payload.removeValue(forKey: "turn_id"); unidentified["payload"] = payload
    for copy in [[timingMeta(), timingStart, timingResponse("a"), unidentified, timingEnd()],
                 [timingMeta(), unidentified]] {
        try logs.write(copy, name: "copy.jsonl", archived: true)
        let rows = try logs.scan().records(in: .all)
        #expect(rows.count == 2)
        #expect(rows.first { $0.requestID == "unidentified" }?.turnPerformance == nil)
        #expect(rows.first { $0.requestID == "a" }?.turnPerformance?.durationMilliseconds == 120_000)
        #expect(rows.first { $0.requestID == "a" }?.turnPerformance?.outputTokens == nil)
    }
}

@Test func unknownTurnAndTimestampInPhysicalCopyCannotProveMeanCoverage() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    try logs.write([timingMeta(), timingStart, timingResponse("a"), timingEnd()])
    var unidentified = timingResponse("unidentified", output: 100)
    unidentified.removeValue(forKey: "timestamp")
    var payload = unidentified["payload"] as! [String: Any]
    payload.removeValue(forKey: "turn_id"); unidentified["payload"] = payload
    try logs.write([timingMeta(), unidentified], name: "copy.jsonl", archived: true)
    let row = try #require(try logs.scan().records(in: .all).first)
    #expect(row.requestID == "a")
    #expect(row.turnPerformance?.durationMilliseconds == 120_000)
    #expect(row.turnPerformance?.outputTokens == nil)
}

@Test func excludedPhysicalCumulativeFrameCannotProveMeanCoverage() throws {
    let logs = TimingLogs(); defer { logs.remove() }
    let a = timingResponse("a")
    try logs.write([timingMeta(), timingStart, a, a, a, timingEnd()])
    let counter = timingEvent("token_count", at: "2026-10-14T00:00:30Z", fields: ["info": ["total_token_usage": ["input_tokens": 500, "output_tokens": 100]]])
    try logs.write([timingMeta(), counter], name: "copy.jsonl", archived: true)
    let report = try logs.scan()
    #expect(report.records(in: .all).count == 1)
    #expect(report.totals(in: .all).output == 20)
    let row = try #require(report.records(in: .all).first)
    #expect(row.turnPerformance?.durationMilliseconds == 120_000)
    #expect(row.turnPerformance?.outputTokens == nil)
}
