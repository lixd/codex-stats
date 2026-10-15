import Foundation
import Testing
@testable import CodexStatsCore

private struct EstimateLogs {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    func write(_ lines: [[String: Any]], name: String = "estimate.jsonl", archived: Bool = false, corruptAfter: Int? = nil) throws {
        let folder = root.appendingPathComponent(archived ? "archived_sessions" : "sessions")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var data = Data()
        for (index, line) in lines.enumerated() {
            data.append(try JSONSerialization.data(withJSONObject: line)); data.append(10)
            if corruptAfter == index { data.append(Data("{broken\n".utf8)) }
        }
        try data.write(to: folder.appendingPathComponent(name))
    }
    func rows() throws -> [UsageRecord] { try CodexLogScanner(timeZone: TimeZone(secondsFromGMT: 0)!).scan(homePath: root.path).records(in: .all) }
    func remove() { try? FileManager.default.removeItem(at: root) }
}
private func estimateLine(_ type: String, _ time: String, _ payload: [String: Any] = [:]) -> [String: Any] {
    ["type": type, "timestamp": "2026-10-14T\(time)Z", "payload": payload]
}
private let estimateMeta = estimateLine("session_meta", "00:00:00", ["id": "owner", "cwd": "/example/project"])
private func estimateContext(_ time: String = "00:00:00", model: String = "A") -> [String: Any] {
    estimateLine("turn_context", time, ["turn_id": "turn", "model": model])
}
private func estimateOutput(_ time: String = "00:00:10", type: String = "message") -> [String: Any] {
    estimateLine("response_item", time, ["type": type, "role": "assistant"])
}
private func estimateUsage(_ id: String = "a", _ time: String = "00:00:12", output: Int = 600) -> [String: Any] {
    estimateLine("token_usage_record", time, ["response_id": id, "thread_id": "owner", "turn_id": "turn",
        "usage": ["input_tokens": 1000, "cached_input_tokens": 800, "output_tokens": output, "reasoning_output_tokens": 100]])
}
private func estimateCounter(_ time: String = "00:00:50") -> [String: Any] {
    estimateLine("event_msg", time, ["type": "token_count", "info": ["last_token_usage":
        ["input_tokens": 1000, "cached_input_tokens": 800, "output_tokens": 600, "reasoning_output_tokens": 100]]])
}

@Test func requestEstimateIncludesWaitingAndEndsAtNativeUsageBeforeDelayedNotification() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(type: "function_call"), estimateUsage(),
        estimateLine("response_item", "00:00:50", ["type": "function_call_output"]), estimateCounter()])
    let rows = try logs.rows()
    #expect(rows.count == 1)
    let estimate = try #require(rows[0].requestEstimate)
    #expect(estimate.durationMilliseconds == 12_000)
    #expect(estimate.outputTokensPerSecond == 50)
    #expect(rows[0].usage.total == 1600)
    #expect(rows[0].turnPerformance == nil)
}

@Test func requestEstimateFreezesFirstOutputBoundaryAndUsesToolReturnForNextModel() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(type: "reasoning"),
        estimateLine("response_item", "00:00:11", ["type": "message", "role": "developer"]), estimateUsage(),
        estimateLine("response_item", "00:00:50", ["type": "custom_tool_call_output"]), estimateCounter(), estimateCounter(),
        estimateContext("00:00:51", model: "B"), estimateOutput("00:01:00"), estimateUsage("b", "00:01:05")])
    let rows = try logs.rows().sorted { $0.timestamp < $1.timestamp }
    #expect(rows.map(\.model) == ["A", "B"])
    #expect(rows.map { $0.requestEstimate?.durationMilliseconds } == [12_000, 14_000])
}

@Test func usageTimestampAloneCannotStartNextRequest() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage(), estimateUsage(),
        estimateOutput("00:00:20"), estimateUsage("b", "00:00:22")])
    let rows = try logs.rows().sorted { $0.timestamp < $1.timestamp }
    #expect(rows.count == 2)
    #expect(rows[0].requestEstimate != nil)
    #expect(rows[1].requestEstimate == nil)
}

@Test func trailingSameFlushOutputCannotBorrowNextToolBoundary() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage(),
        estimateLine("response_item", "00:00:12.010", ["type": "function_call_output"]),
        estimateOutput("00:00:12.050"), estimateUsage("b", "00:00:12.080")])
    let rows = try logs.rows().sorted { $0.timestamp < $1.timestamp }
    #expect(rows[1].requestEstimate == nil)
}

@Test(arguments: ["00:00:00.050", "01:00:00.001", "00:00:00.100"])
func requestDurationBoundsAreNotClamped(end: String) throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput("00:00:00.010"), estimateUsage("a", end)])
    let row = try #require(try logs.rows().first)
    if end == "00:00:00.100" {
        #expect(row.requestEstimate?.durationMilliseconds == 100)
        #expect(row.requestEstimate?.outputTokensPerSecond == nil)
    } else { #expect(row.requestEstimate == nil) }
}

@Test(arguments: [199, 200]) func estimatedSpeedRequiresEnoughOutput(output: Int) throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage(output: output)])
    let estimate = try #require(try logs.rows().first?.requestEstimate)
    #expect((estimate.outputTokensPerSecond != nil) == (output >= 200))
}

@Test func abortAndTaskStartDiscardUnfinishedRequestOrigin() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(),
        estimateLine("event_msg", "00:00:11", ["type": "turn_aborted", "turn_id": "turn"]), estimateUsage()])
    #expect(try logs.rows().first?.requestEstimate == nil)
    try logs.write([estimateMeta, estimateContext(), estimateOutput(),
        estimateLine("event_msg", "00:00:30", ["type": "task_started", "turn_id": "new"]), estimateUsage("a", "00:00:40")])
    #expect(try logs.rows().first?.requestEstimate == nil)
}

@Test func malformedLineInvalidatesPendingEstimateWithoutDroppingUsage() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage()], corruptAfter: 2)
    let row = try #require(try logs.rows().first)
    #expect(row.usage.total == 1600)
    #expect(row.requestEstimate == nil)
}

@Test func cumulativeAndInitialSnapshotsNeverGetPerRequestEstimates() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    var counter = estimateCounter()
    var payload = counter["payload"] as! [String: Any]
    payload["info"] = ["total_token_usage": ["input_tokens": 1000, "output_tokens": 600]]
    counter["payload"] = payload
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), counter])
    let initialRows = try logs.rows()
    #expect(initialRows.count == 1)
    #expect(initialRows[0].evidence == .initialSnapshot)
    #expect(initialRows[0].requestEstimate == nil)
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateCounter(),
        estimateOutput("00:01:00"), estimateUsage("b", "00:01:10")])
    #expect(try logs.rows().allSatisfy { $0.requestEstimate == nil })
}

@Test func duplicateCopiesPreserveEstimateButConflictingBoundariesInvalidateIt() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    let lines = [estimateMeta, estimateContext(), estimateOutput(), estimateUsage()]
    try logs.write(lines); try logs.write(lines, name: "copy.jsonl", archived: true)
    #expect(try logs.rows().count == 1)
    #expect(try logs.rows().first?.requestEstimate?.durationMilliseconds == 12_000)
    try logs.write([estimateMeta, estimateContext("00:00:05"), estimateOutput(), estimateUsage()], name: "copy.jsonl", archived: true)
    #expect(try logs.rows().first?.requestEstimate == nil)
}

@Test func compactionResponseDoesNotReceiveRequestSpeed() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage(),
        estimateLine("compacted", "00:00:13", ["compaction_response_id": "a"])])
    let row = try #require(try logs.rows().first)
    #expect(row.isCompaction)
    #expect(row.requestEstimate == nil)
}

@Test func itemEnvelopeDurationCannotBeUsedAsRequestEstimate() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateLine("item_completed", "00:00:10",
        ["started_at_ms": 1000, "completed_at_ms": 1001, "item": ["type": "message"]]), estimateUsage()])
    #expect(try logs.rows().first?.requestEstimate == nil)
}

@Test func anonymousAbortAlsoInvalidatesEarlierRequestEstimates() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), estimateUsage(),
        estimateLine("event_msg", "00:00:20", ["type": "turn_aborted"])])
    #expect(try logs.rows().first?.requestEstimate == nil)
}

@Test func exactOneSecondEstimateCanShowRateAndDifferentTurnCannotBorrowBoundary() throws {
    let logs = EstimateLogs(); defer { logs.remove() }
    try logs.write([estimateMeta, estimateContext(), estimateOutput("00:00:00.500"), estimateUsage("a", "00:00:01", output: 200)])
    #expect(try logs.rows().first?.requestEstimate?.outputTokensPerSecond == 200)
    var native = estimateUsage()
    var payload = native["payload"] as! [String: Any]; payload["turn_id"] = "other"; native["payload"] = payload
    try logs.write([estimateMeta, estimateContext(), estimateOutput(), native])
    #expect(try logs.rows().first?.requestEstimate == nil)
}
