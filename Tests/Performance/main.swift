import Foundation

struct Snapshot: Codable, Equatable {
    struct Row: Codable, Equatable {
        let id, session, model, day, evidence: String
        let request, turn, recordedSession: String?
        let project, source, file: String
        let cumulative, lastReported: TokenUsage?
        let milliseconds: Int64
        let usage: TokenUsage
        let compaction: Bool
    }
    struct Slice: Codable, Equatable { let session, day, model: String; let usage: TokenUsage }
    struct Hour: Codable, Equatable { let session: String; let milliseconds: Int64; let usage: TokenUsage }
    struct Model: Codable, Equatable { let usage: TokenUsage; let sessionCount: Int }
    struct Period: Codable, Equatable { let name: String; let rows: [String]; let usage: TokenUsage; let models: [String: Model]; let days: [String: TokenUsage]; let sessions: [String] }
    let rows: [Row]
    let slices: [Slice]
    let hours: [Hour]
    let periods: [Period]
    let diagnostics: [ScanDiagnostic]
}
func milliseconds(_ value: Date) -> Int64 { Int64((value.timeIntervalSince1970 * 1_000).rounded()) }
func timed<T>(_ work: () throws -> T) rethrows -> (T, Double) {
    let start = ProcessInfo.processInfo.systemUptime
    return (try work(), ProcessInfo.processInfo.systemUptime - start)
}
let args = CommandLine.arguments
let root = args[1], output = args[2]
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: root).appendingPathComponent("manifest.json"))) as! [String: Any]
precondition(manifest["synthetic"] as? String == "codex-stats-performance-v1", "Only generated synthetic fixtures may be mutated")
let expected = TokenUsage.fromJSONObject(manifest["usage"])!
let fileCount = manifest["files"] as! Int, recordCount = manifest["records"] as! Int
let now = ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z")!
let scanner = CodexLogScanner()
let (report, cold) = try timed { try scanner.scan(homePath: root) }
precondition(report.totals(in: .all) == expected)
precondition(report.fileCount == fileCount)
precondition(report.records(in: .all).count == recordCount)
precondition(report.warnings.isEmpty)
let rows = report.records(in: .all)
precondition(rows.reduce(TokenUsage()) { $0 + $1.usage } == expected)
precondition(Set(rows.map(\.id)).count == recordCount)
for session in report.sessions {
    precondition(session.records.reduce(TokenUsage()) { $0 + $1.usage } == session.usage(in: .all))
    precondition(session.hourlyUsage.values.reduce(TokenUsage()) { $0 + $1 } == session.usage(in: .all))
}
var periods: [Snapshot.Period] = []
var filtering: [String: Double] = [:]
for period in UsagePeriod.allCases {
    let (records, duration) = timed { report.records(in: period, now: now) }
    filtering[period.rawValue] = duration
    let total = report.totals(in: period, now: now)
    precondition(records.reduce(TokenUsage()) { $0 + $1.usage } == total)
    let models = Dictionary(uniqueKeysWithValues: report.models(in: period, now: now).map { ($0.model, $0.usage) })
    let days = Dictionary(uniqueKeysWithValues: report.dailyTotals(in: period, now: now).map { ($0.day, $0.usage) })
    precondition(models.values.reduce(TokenUsage()) { $0 + $1 } == total)
    precondition(days.values.reduce(TokenUsage()) { $0 + $1 } == total)
    periods.append(.init(name: period.rawValue, rows: records.map(\.id), usage: total, models: Dictionary(uniqueKeysWithValues: report.models(in: period, now: now).map { ($0.model, Snapshot.Model(usage: $0.usage, sessionCount: $0.sessionCount)) }), days: days,
                         sessions: report.recentSessions(in: period, now: now).map(\.id)))
}
let snapshot = Snapshot(rows: rows.map { .init(id: $0.id, session: $0.sessionID, model: $0.model, day: $0.day,
    evidence: $0.evidence.rawValue, request: $0.requestID, turn: $0.turnID, recordedSession: $0.recordedSessionID, project: $0.project, source: $0.source, file: $0.fileName, cumulative: $0.cumulativeSnapshot, lastReported: $0.lastReportedUsage, milliseconds: milliseconds($0.timestamp), usage: $0.usage, compaction: $0.isCompaction) },
    slices: report.sessions.flatMap { session in session.dailyModel.map { .init(session: session.id, day: $0.day, model: $0.model, usage: $0.usage) } }.sorted { ($0.session, $0.day, $0.model) < ($1.session, $1.day, $1.model) },
    hours: report.sessions.flatMap { session in session.hourlyUsage.map { .init(session: session.id, milliseconds: milliseconds($0.key), usage: $0.value) } }.sorted { ($0.session, $0.milliseconds) < ($1.session, $1.milliseconds) },
    periods: periods, diagnostics: report.diagnostics)
let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
try encoder.encode(snapshot).write(to: URL(fileURLWithPath: output + "-snapshot.json"))
let (warm, warmTime) = try timed { try scanner.scan(homePath: root) }
precondition(warm.cachedFileCount == fileCount && warm.totals(in: .all) == expected)
let extra = TokenUsage(input: 500, cachedInput: 400, output: 25, reasoning: 5)
let event: [String: Any] = ["type": "token_usage_record", "timestamp": "2026-10-14T12:00:00.999Z", "payload": [
    "thread_id": "session-00", "turn_id": "append-turn", "response_id": "controlled-append",
    "model": "model-alpha", "usage": ["input_tokens": 500, "cached_input_tokens": 400, "output_tokens": 25, "reasoning_output_tokens": 5]]]
let file = URL(fileURLWithPath: root).appendingPathComponent("sessions/synthetic-00.jsonl")
let originalSize = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! NSNumber).uint64Value
let handle = try FileHandle(forWritingTo: file)
try handle.seekToEnd(); try handle.write(contentsOf: JSONSerialization.data(withJSONObject: event, options: [.sortedKeys])); try handle.write(contentsOf: Data([10])); try handle.close()
let (appended, appendTime) = try timed { try scanner.scan(homePath: root) }
// Restore ONLY the generated synthetic fixture, never touch user logs.
let restore = try FileHandle(forWritingTo: file); try restore.truncate(atOffset: originalSize); try restore.close()
precondition(appended.cachedFileCount == fileCount - 1)
precondition(appended.totals(in: .all) == expected + extra)
precondition(appended.records(in: .all).count == recordCount + 1)
let metrics: [String: Any] = ["coldSeconds": cold, "warmSeconds": warmTime, "appendSeconds": appendTime,
    "filterSeconds": filtering, "files": fileCount, "records": recordCount, "bytes": manifest["bytes"]!, "total": expected.total]
let metricsData = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
try metricsData.write(to: URL(fileURLWithPath: output + "-metrics.json"))
print(String(decoding: metricsData, as: UTF8.self))
