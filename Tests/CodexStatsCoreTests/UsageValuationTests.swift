import Foundation
import Testing
@testable import CodexStatsCore

@Test func cacheRateStatesAndWeighting() {
    #expect(CacheRate(usage: TokenUsage(input: 1000, cachedInput: 800)).fraction == 0.8)
    let combined = TokenUsage(input: 100, cachedInput: 100) + TokenUsage(input: 900)
    #expect(CacheRate(usage: combined).fraction == 0.1)
    #expect(CacheRate(usage: TokenUsage(input: 100)).fraction == 0)
    #expect(CacheRate(usage: TokenUsage(cachedInputKnown: false)).state == .noInput)
    #expect(CacheRate(usage: TokenUsage(input: 100, cachedInputKnown: false)).state == .incomplete)
}

@Test func costHandOracleAndReasoningSubset() {
    let usage = TokenUsage(input: 1000, cachedInput: 800, output: 100, reasoning: 50)
    let expected = ["gpt-6.1-sol": "0.00148", "gpt-6-astra": "0.0078", "gpt-6-luna": "0.000078", "gpt-5.3-codex": "0.00189", "gpt-5.6-sol": "0.00312", "gpt-6-sol": "0.00156"]
    for (model, value) in expected {
        let result = CostEstimate.calculate(usage: usage, model: model)
        #expect(result.amountUSD == Decimal(string: value)!)
        #expect(result.state == .complete && result.estimatedTokens == 1100)
        #expect(result == .calculate(usage: TokenUsage(input: 1000, cachedInput: 800, output: 100), model: model))
    }
    #expect(ReferencePricing.prices.count == 6)
    #expect(ReferencePricing.version == "openai-standard-short-2026-10-15-r2")
    #expect(CostEstimate.calculate(usage: usage, model: "GPT-6.1-SOL").state == .unavailable)
    #expect(CostEstimate.calculate(usage: usage, model: "gpt-6.1-sol-extra").state == .unavailable)
}

@Test func costCoverageUnknownZeroAndOutputOnly() throws {
    let known = CostEstimate.calculate(usage: TokenUsage(input: 1000, cachedInput: 800, output: 100), model: "gpt-6.1-sol")
    let missing = CostEstimate.calculate(usage: TokenUsage(input: 100, output: 10, cachedInputKnown: false), model: "gpt-6.1-sol")
    let unpriced = CostEstimate.calculate(usage: TokenUsage(input: 200), model: "Unknown model")
    var combined = known; combined.merge(missing); combined.merge(unpriced)
    #expect(combined.state == .partial && combined.amountUSD == Decimal(string: "0.00148")!)
    #expect(combined.estimatedTokens == 1100 && combined.unestimatedTokens == 310)
    #expect(combined.reasons == [.incompleteCachedInput: 1, .missingPrice: 1])
    let onlyOutput = CostEstimate.calculate(usage: TokenUsage(output: 100, cachedInputKnown: false), model: "gpt-6.1-sol")
    #expect(onlyOutput.amountUSD == Decimal(string: "0.001")! && onlyOutput.state == .complete)
    let zero = CostEstimate.calculate(usage: TokenUsage(cachedInputKnown: false), model: "Unknown model")
    #expect(zero.state == .complete && zero.amountUSD == 0 && zero.reasons.isEmpty)
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(missing)) as! [String: Any]
    #expect(json["amountUSD"] is NSNull)
    #expect(json["state"] as? String == "unavailable")
    let zeroJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(zero)) as! [String: Any]
    #expect(zeroJSON["amountUSD"] as? String == "0")
}

@Test func costExactSmallLargeAndArithmeticFailure() {
    let tiny = CostEstimate.calculate(usage: TokenUsage(input: 1), model: "gpt-6-luna")
    #expect(tiny.amountUSD == Decimal(string: "0.0000001")!)
    let huge = CostEstimate.calculate(usage: TokenUsage(input: 1_234_567_890_123_456, cachedInput: 0), model: "gpt-6.1-sol")
    #expect(huge.amountUSD == Decimal(string: "2469135780.246912")!)
    var combined = tiny
    for _ in 0..<99 { combined.merge(tiny) }
    #expect(combined.amountUSD == Decimal(string: "0.00001")!)
    let invalid = ReferencePrice(input: .nan, cachedInput: 0, output: 0)
    #expect(CostEstimate.calculate(usage: TokenUsage(input: 1), price: invalid).reasons == [.calculationFailure: 1])
    let overflow = ReferencePrice(input: Decimal.greatestFiniteMagnitude, cachedInput: 0, output: 0)
    #expect(CostEstimate.calculate(usage: TokenUsage(input: 1000), price: overflow).state == .unavailable)
}

private func valuationRecord(_ id: String, session: String = "session", day: String = "2026-10-14", model: String = "gpt-6.1-sol", usage: TokenUsage) -> UsageRecord {
    UsageRecord(id: id, sessionID: session, recordedSessionID: session, project: "synthetic", source: "test", fileName: "synthetic.jsonl",
                timestamp: ISO8601DateFormatter().date(from: day + "T12:00:00Z")!, day: day, model: model, requestID: id, turnID: nil,
                usage: usage, evidence: .responseRecord, isCompaction: id == "compact", cumulativeSnapshot: nil, lastReportedUsage: nil)
}
private func valuationSession(_ id: String, records: [UsageRecord]) -> SessionUsage {
    SessionUsage(id: id, project: "synthetic", title: id, workingDirectory: "", source: "test", isFork: false,
                 replayDeduplicated: false, replayUnverified: false, firstActivity: records.first!.timestamp, lastActivity: records.last!.timestamp,
                 dailyModel: records.map { DailyModelUsage(day: $0.day, model: $0.model, usage: $0.usage) }, fileName: "synthetic", records: records)
}

@Test func scalarIndexPreservesPartialRecordsAndAllGroupSums() {
    let a = valuationRecord("a", usage: TokenUsage(input: 1000, cachedInput: 800, output: 100))
    let b = valuationRecord("b", usage: TokenUsage(input: 100, output: 10, cachedInputKnown: false))
    let c = valuationRecord("compact", session: "second", day: "2026-10-15", model: "gpt-6-astra", usage: TokenUsage(output: 100))
    let report = ScanReport(sessions: [valuationSession("session", records: [a, b]), valuationSession("second", records: [c])],
                            fileCount: 2, invalidLineCount: 0, diagnostics: [], refreshedAt: Date())
    let index = ValuationIndex(report: report)
    #expect(index.bucketCount == 2)
    let all = index.summary(in: .all)
    #expect(all.total.amountUSD == Decimal(string: "0.00648")!)
    #expect(all.total.estimatedTokens == 1200 && all.total.unestimatedTokens == 110)
    #expect(all.models["gpt-6.1-sol"]?.amountUSD == Decimal(string: "0.00148")!)
    #expect(all.models["gpt-6.1-sol"]?.state == .partial)
    var sessions = CostEstimate(), models = CostEstimate(), direct = CostEstimate()
    all.sessions.values.forEach { sessions.merge($0) }
    all.models.values.forEach { models.merge($0) }
    report.sessions.forEach { $0.records.forEach { direct.merge(.calculate(usage: $0.usage, model: $0.model)) } }
    #expect(sessions == all.total && models == all.total && direct == all.total)
    #expect(all.sessionModels["session"]?["gpt-6.1-sol"] == all.sessions["session"])
    let now = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!
    let today = index.summary(in: .today, now: now)
    #expect(today.total.amountUSD == Decimal(string: "0.005")!)
    #expect(today.total.estimatedTokens == 100 && today.total.state == .complete)
    #expect(index.summary(in: .sevenDays, now: now).total == all.total)
    #expect(index.summary(in: .today, now: now.addingTimeInterval(86400)).total == CostEstimate())
    #expect(ValuationIndex(report: .empty).summary(in: .all).total.state == .complete)
}
