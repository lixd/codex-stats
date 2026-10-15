import Foundation
import CoreFoundation

/// Read-only JSONL scanner. Call serially (the app owns it on a background actor).
/// Unchanged files reuse parsed token metadata; prompts and response bodies are never retained.
public final class CodexLogScanner {
    private struct Stamp: Equatable { let size: Int64; let modified: Date }
    private struct CachedFile { let stamp: Stamp; let log: ParsedLog }
    private var cache: [String: CachedFile] = [:]
    private let fractionalDate = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private let wholeDate = Date.ISO8601FormatStyle()
    private let timeZone: TimeZone

    public init(timeZone: TimeZone = .current) { self.timeZone = timeZone }

    // Trust Gregorian RFC3339 clocks, not Foundation's normalization of invalid
    // dates/times. Keep the previous millisecond precision for valid records.
    func parseTimestamp(_ raw: String) -> Date? {
        let bytes = Array(raw.utf8)
        guard bytes.count >= 20, bytes[4] == 45, bytes[7] == 45,
              bytes[10] == 84 || bytes[10] == 116, bytes[13] == 58, bytes[16] == 58 else { return nil }
        func number(_ start: Int, _ count: Int) -> Int? {
            guard start + count <= bytes.count else { return nil }
            var value = 0
            for byte in bytes[start..<(start + count)] {
                guard byte >= 48 && byte <= 57 else { return nil }
                value = value * 10 + Int(byte - 48)
            }
            return value
        }
        guard let year = number(0, 4), let month = number(5, 2), let day = number(8, 2),
              year > 0, month >= 1, month <= 12,
              let hour = number(11, 2), hour < 24,
              let minute = number(14, 2), minute < 60,
              let second = number(17, 2), second < 60 else { return nil }
        let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
        let days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard day >= 1 && day <= days[month - 1] else { return nil }
        var end = 19
        var normalized = String(decoding: bytes.prefix(end), as: UTF8.self)
        if bytes[end] == 46 {
            let start = end + 1
            end = start
            while end < bytes.count && bytes[end] >= 48 && bytes[end] <= 57 { end += 1 }
            guard end > start else { return nil }
            normalized += "." + String(decoding: bytes[start..<min(end, start + 3)], as: UTF8.self)
        }
        guard end < bytes.count else { return nil }
        var offset = 0
        if bytes[end] == 90 || bytes[end] == 122 {
            guard end + 1 == bytes.count else { return nil }
        } else {
            guard bytes[end] == 43 || bytes[end] == 45 else { return nil }
            let remaining = bytes.count - end
            guard remaining == 5 || (remaining == 6 && bytes[end + 3] == 58),
                  let hours = number(end + 1, 2), hours < 24,
                  let minutes = number(end + (remaining == 6 ? 4 : 3), 2), minutes < 60 else { return nil }
            offset = (hours * 3_600 + minutes * 60) * (bytes[end] == 43 ? 1 : -1)
        }
        // Parse the wall clock at Z and apply its explicit offset. This also covers
        // valid RFC3339 offsets beyond Foundation's fixed-zone limit of 18 hours.
        normalized += "Z"
        guard let date = (try? fractionalDate.parse(normalized)) ?? (try? wholeDate.parse(normalized)) else { return nil }
        let epoch = date.timeIntervalSince1970 - Double(offset)
        return Date(timeIntervalSince1970: (epoch * 1_000).rounded() / 1_000)
    }

    public func scan(homePath: String) throws -> ScanReport {
        let roots = homePath.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }.map {
            URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath)
        }
        guard !roots.isEmpty else { throw ScannerError.invalidLocation }
        let fm = FileManager.default
        var files = Set<URL>()
        var diagnostics: [ScanDiagnostic] = []
        for root in roots {
            var directory: ObjCBool = false
            guard fm.fileExists(atPath: root.path, isDirectory: &directory), directory.boolValue else {
                throw ScannerError.missingFolder(root.path)
            }
            let folders = ["sessions", "archived_sessions"].map { root.appendingPathComponent($0) }
            // A Codex home is never scanned recursively outside its two log folders.
            // A direct JSONL directory can also be selected explicitly.
            let isHome = root.lastPathComponent == ".codex" || folders.contains { fm.fileExists(atPath: $0.path) }
            for folder in isHome ? folders : [root] where fm.fileExists(atPath: folder.path) {
                guard let iterator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in
                        diagnostics.append(.init(severity: .error, kind: .unreadableFile, fileName: url.lastPathComponent, message: "无法枚举 \(url.lastPathComponent)：\(error.localizedDescription)"))
                        return true
                    }) else {
                    diagnostics.append(.init(severity: .error, kind: .unreadableFile, message: "无法枚举日志目录：\(folder.path)"))
                    continue
                }
                for case let url as URL in iterator {
                    guard url.pathExtension == "jsonl",
                          let properties = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                          properties.isRegularFile == true, properties.isSymbolicLink != true else { continue }
                    files.insert(url.standardizedFileURL)
                }
            }
        }
        var logs: [ParsedLog] = []
        var hits = 0
        for url in files.sorted(by: { $0.path < $1.path }) {
            do {
                let attr = try fm.attributesOfItem(atPath: url.path)
                let stamp = Stamp(size: (attr[.size] as? NSNumber)?.int64Value ?? 0,
                                  modified: attr[.modificationDate] as? Date ?? .distantPast)
                if let hit = cache[url.path], hit.stamp == stamp { logs.append(hit.log); hits += 1 }
                else {
                    let log = try parseFile(url, fallbackDate: stamp.modified)
                    cache[url.path] = CachedFile(stamp: stamp, log: log)
                    logs.append(log)
                }
            } catch { diagnostics.append(.init(severity: .error, kind: .unreadableFile, fileName: url.lastPathComponent, message: "无法读取 \(url.lastPathComponent)：\(error.localizedDescription)")) }
        }
        let paths = Set(files.map(\.path))
        cache = cache.filter { paths.contains($0.key) }
        normalizeCompaction(&logs)
        // Stable SessionMeta.id groups the UI, not the immutable physical rollout.
        // Independent native response identities survive revert and remain expenditure.
        let groups = Dictionary(grouping: logs, by: \.id)
        let selected = groups.mapValues { copies in
            copies.sorted {
                if $0.frames.count != $1.frames.count { return $0.frames.count > $1.frames.count }
                if $0.archived != $1.archived { return !$0.archived }
                return $0.path < $1.path
            }[0]
        }
        diagnostics += historyDiagnostics(logs)
        var responses: [String: Frame] = [:]
        var conflicting = Set<String>()
        for log in logs {
            for frame in log.frames where frame.owner == log.id {
                guard let response = frame.responseID else { continue }
                if let old = responses[response], !sameResponse(old, frame) {
                    conflicting.insert(response)
                } else { responses[response] = frame }
            }
        }
        for log in logs where log.frames.contains(where: {
            $0.owner == log.id && $0.responseID.map { conflicting.contains($0) } == true
        }) {
            diagnostics.append(.init(severity: .warning, kind: .conflictingResponse,
                sessionID: log.id, fileName: log.fileName,
                message: "\(log.id.prefix(8))：同一 response_id 的用量或归属冲突，该身份未计入；统计不完整。"))
        }
        var sessions: [SessionUsage] = []
        var seenResponses = Set<String>()
        var countedUsage = TokenUsage()
        for id in groups.keys.sorted() {
            let copies = groups[id]!
            let primary = selected[id]!
            let parent = primary.parentId.flatMap { selected[$0] }
            var slices: [DailyModelUsage] = []
            var hours: [Date: TokenUsage] = [:]
            var records: [UsageRecord] = []
            var foreign = 0
            var inheritedCount = 0
            var unverified = false
            var hasAcceptedLegacy = false
            for log in [primary] + copies.filter({ $0.path != primary.path }).sorted(by: { $0.path < $1.path }) {
                let inherited = inheritedPrefix(child: log, parent: parent)
                let result = aggregate(log, inherited: inherited, seenResponses: &seenResponses,
                    countedUsage: &countedUsage, conflicting: conflicting,
                    allowLegacy: log.path == primary.path, allowNative: log.path == primary.path || !hasAcceptedLegacy)
                if log.path == primary.path { hasAcceptedLegacy = result.records.contains { $0.evidence != .responseRecord } }
                slices += result.slices
                for (hour, usage) in result.hours { hours[hour, default: TokenUsage()] += usage }
                records += result.records
                foreign += result.foreignRecords
                inheritedCount += inherited
                diagnostics += log.diagnostics + result.diagnostics
                unverified = unverified || (log.isFork && inherited == 0 && !log.frames.isEmpty &&
                    !log.frames.contains { $0.responseID != nil && $0.owner == log.id })
                if log.path != primary.path {
                    let safeCopy = accountingCopy(log, primary)
                    if safeCopy {
                        diagnostics.append(.init(severity: .information, kind: .supersededCopy,
                            sessionID: id, fileName: log.fileName, message: "\(id.prefix(8))：已核验重复或非空前缀副本，未重复计量。"))
                    } else if !hasAcceptedLegacy && result.records.count > 0 &&
                        log.frames.filter({ $0.owner == nil }).isEmpty {
                        diagnostics.append(.init(severity: .information, kind: .mergedPhysicalHistory,
                            sessionID: id, fileName: log.fileName, message: "\(id.prefix(8))：已计入不同物理历史中的独立请求，按 response_id 去重。"))
                    } else if !hasAcceptedLegacy && nativeOnlyAccounting(log) && nativeOnlyAccounting(primary) {
                        diagnostics.append(.init(severity: .information, kind: .mergedPhysicalHistory,
                            sessionID: id, fileName: log.fileName, message: "\(id.prefix(8))：已核验原生请求记录并按 response_id 合并物理历史。"))
                    } else {
                        diagnostics.append(.init(severity: .warning, kind: .divergentAccountingCopies,
                            sessionID: id, fileName: log.fileName,
                            message: "\(id.prefix(8))：不同副本的旧计量覆盖无法核实，保留所选旧格式流；其他无法证明不重叠的用量未合并，可能少计。"))
                    }
                }
            }
            if unverified { diagnostics.append(.init(severity: .warning, kind: .inheritedHistory, sessionID: id,
                message: "\(id.prefix(8))：无法核实子会话继承边界，旧格式用量可能包含历史。")) }
            // Display the latest metadata, while activity bounds and usage span all generations.
            let metadata = copies.sorted { $0.lastActivity != $1.lastActivity ? $0.lastActivity > $1.lastActivity : $0.path < $1.path }[0]
            var merged: [DayModel: TokenUsage] = [:]
            for slice in slices { merged[DayModel(day: slice.day, model: slice.model), default: TokenUsage()] += slice.usage }
            sessions.append(SessionUsage(id: id, project: metadata.project, title: "\(metadata.project) · \(id.prefix(8))",
                workingDirectory: metadata.cwd, source: metadata.source, isFork: copies.contains { $0.isFork },
                replayDeduplicated: inheritedCount > 0 || foreign > 0, replayUnverified: unverified,
                firstActivity: copies.map(\.started).min()!, lastActivity: copies.map(\.lastActivity).max()!,
                dailyModel: merged.map { .init(day: $0.key.day, model: $0.key.model, usage: $0.value) }.sorted { ($0.day, $0.model) < ($1.day, $1.model) },
                fileName: metadata.fileName, hourlyUsage: hours, records: records.sorted { ($0.timestamp, $0.id) < ($1.timestamp, $1.id) }))
        }
        attachTurnPerformance(to: &sessions, logs: logs, conflicting: conflicting)
        attachRequestEstimates(to: &sessions, logs: logs)
        let invalid = logs.reduce(0) { $0 + $1.invalidLines }
        return ScanReport(sessions: sessions.sorted { $0.lastActivity > $1.lastActivity }, fileCount: files.count,
            invalidLineCount: invalid, diagnostics: Array(Set(diagnostics)).sorted { ($0.severity.rawValue, $0.kind.rawValue, $0.message, $0.fileName ?? "") < ($1.severity.rawValue, $1.kind.rawValue, $1.message, $1.fileName ?? "") },
            refreshedAt: Date(), cachedFileCount: hits)
    }

    public enum ScannerError: LocalizedError {
        case invalidLocation, missingFolder(String)
        public var errorDescription: String? {
            switch self {
            case .invalidLocation: return "没有设置 Codex 日志目录"
            case .missingFolder(let path): return "找不到 Codex 日志目录：\(path)"
            }
        }
    }
}

private struct Frame: Equatable {
    let timestamp: Date?
    var model: String
    var explicitModel = false
    let turn: String?
    let cumulative: TokenUsage?
    let last: TokenUsage?
    let responseID: String?
    let owner: String?
    var identityIsResponseID = true
    var isCompaction = false
    var isNative = false
    var explicitTurn = false
}
private struct ParsedLog {
    let id: String
    let recordedSessionID: String?
    let cwd: String
    let project: String
    let source: String
    let started: Date
    let lastActivity: Date
    let parentId: String?
    let isFork: Bool
    let hasHistoryBase: Bool
    let history: HistoryReference?
    let physicalID: String
    let path: String
    let boundaries: [Int64: UInt64]
    let incomplete: Bool
    var frames: [Frame]
    let invalidLines: Int
    let invalidLineOffsets: [Int64]
    let diagnostics: [ScanDiagnostic]
    let fileName: String
    let archived: Bool
    let turns: [TurnTiming]
    let failedTurns: Set<String>
    let requestEstimates: [String: RequestEstimate]
    let conflictingEstimates: Set<String>
}
/// Retains timestamps only, never model output or tool contents.
private struct RequestTimer {
    var boundary: Date?
    var start: Date?
    var lastUsage: Date?
    var turnID: String?

    mutating func reset(at timestamp: Date? = nil, turn: String? = nil) {
        boundary = timestamp
        start = nil
        turnID = turn
    }
    mutating func observeBoundary(_ timestamp: Date?) {
        guard let timestamp else { reset(); return }
        boundary = max(boundary ?? timestamp, timestamp)
    }
    mutating func observeOutput(_ timestamp: Date?) {
        guard let timestamp else { reset(); return }
        // Supplementary output items flushed with a preceding usage row belong
        // to that response, not the next request. Never use item envelope timers.
        if start == nil, let lastUsage, timestamp.timeIntervalSince(lastUsage) <= 0.1 { return }
        if let start, timestamp < start { reset(); return }
        if start == nil, let boundary, timestamp >= boundary { start = boundary }
    }
    mutating func finish(at timestamp: Date?, output: Int64) -> RequestEstimate? {
        let candidateStart = start
        // A usage timestamp alone is not a request-start boundary. A tool result
        // written during this response may, however, start the next response.
        if boundary == start { boundary = nil }
        start = nil
        if let timestamp { lastUsage = max(lastUsage ?? timestamp, timestamp) }
        guard let candidateStart, let timestamp else { return nil }
        let milliseconds = (timestamp.timeIntervalSince(candidateStart) * 1000).rounded()
        guard milliseconds >= 100, milliseconds <= 3_600_000 else { return nil }
        return RequestEstimate(startedAt: candidateStart, completedAt: timestamp,
            durationMilliseconds: Int64(milliseconds), outputTokens: output)
    }
}
private struct TurnTiming: Equatable {
    let id: String
    let started: Date
    let completed: Date
    let duration: Int64
    let firstToken: Int64?
    let responses: Set<String>
    let locallyComplete: Bool
    let frameRange: Range<Int>
}
private struct HistoryReference: Equatable {
    let rolloutID: String
    let endOrdinal: UInt64
    let endByteOffset: Int64
}
private struct DayModel: Hashable { let day: String; let model: String }

private extension CodexLogScanner {
    func parseFile(_ url: URL, fallbackDate: Date) throws -> ParsedLog {
        var id: String?
        var cwd = ""
        var source = "Codex"
        var started = fallbackDate
        var lastActivity = Date.distantPast
        var parent: String?
        var isFork = false
        var hasHistoryBase = false
        var history: HistoryReference?
        var boundaries: [Int64: UInt64] = [:]
        var incomplete = false
        var model = "Unknown model"
        var turn: String?
        var frames: [Frame] = []
        var fallback: [Frame] = []
        var compacted = Set<String>()
        var firstMetaSeen = false
        var invalid = 0
        var invalidLineOffsets: [Int64] = []
        var diagnostics = Set<ScanDiagnostic>()
        var turnStarts: [String: (date: Date, frame: Int, invalid: Int)] = [:]
        var turns: [TurnTiming] = []
        var failedTurns = Set<String>()
        var requestTimer = RequestTimer()
        var lastTimingCounter: (total: TokenUsage?, last: TokenUsage?)?
        var requestEstimates: [String: RequestEstimate] = [:]
        var conflictingEstimates = Set<String>()
        func warn(_ kind: DiagnosticKind, _ message: String, severity: DiagnosticSeverity = .warning) {
            diagnostics.insert(.init(severity: severity, kind: kind, sessionID: id, fileName: url.lastPathComponent, message: message))
        }
        func date(_ raw: Any?) -> Date? {
            guard let raw = raw as? String else { return nil }
            return parseTimestamp(raw)
        }
        func usage(_ raw: Any?) -> TokenUsage? {
            guard raw != nil, !(raw is NSNull) else { return nil }
            let parsed = TokenUsage.fromJSONObject(raw)
            if parsed == nil { warn(.invalidUsage, "存在缺失或非法 Token 字段，已跳过；不会补齐未知用量。") }
            if let parsed, !parsed.cachedInputKnown || !parsed.reasoningKnown {
                warn(.incompleteFields, "缓存/推理字段未完整记录：相关明细显示未完整记录，不将缺失值当作零。")
            }
            return parsed
        }
        try forEachLine(url) { data, complete, endOffset in
            guard let object = try? JSONSerialization.jsonObject(with: data), let value = object as? [String: Any] else {
                if complete { invalid += 1; invalidLineOffsets.append(endOffset); warn(.invalidJSON, "损坏 JSON 行已跳过，统计可能不完整。") }
                else { incomplete = true; warn(.partialWrite, "日志末行尚未写完，等待下次刷新。") }
                requestTimer.reset()
                return
            }
            if complete, let ordinal = unsigned(value["ordinal"]), ordinal < UInt64.max { boundaries[endOffset] = ordinal + 1 }
            let type = value["type"] as? String ?? ""
            let p = value["payload"] as? [String: Any] ?? [:]
            let timestamp = date(value["timestamp"])
            if let timestamp { lastActivity = max(lastActivity, timestamp) }
            switch type {
            case "session_meta":
                guard !firstMetaSeen else { return }
                firstMetaSeen = true
                id = nonempty(p["id"]) ?? nonempty(p["session_id"])
                cwd = p["cwd"] as? String ?? ""
                source = p["originator"] as? String ?? "Codex"
                started = date(p["timestamp"]) ?? timestamp ?? fallbackDate
                parent = p["forked_from_id"] as? String ?? p["parent_thread_id"] as? String
                if let src = p["source"] as? [String: Any], let agent = src["subagent"] as? [String: Any],
                   let spawn = agent["thread_spawn"] as? [String: Any] {
                    parent = parent ?? spawn["parent_thread_id"] as? String
                    isFork = true
                }
                isFork = isFork || parent != nil || p["thread_source"] as? String == "subagent"
                hasHistoryBase = p["history_base"] != nil && !(p["history_base"] is NSNull)
                if let raw = p["history_base"] as? [String: Any], let target = nonempty(raw["thread_id"]),
                   let ordinal = unsigned(raw["end_ordinal_exclusive"]), let offset = unsigned(raw["end_byte_offset"]), offset <= UInt64(Int64.max) {
                    history = HistoryReference(rolloutID: target, endOrdinal: ordinal, endByteOffset: Int64(offset))
                } else if hasHistoryBase { warn(.unresolvedHistoryReference, "history_base 字段无效，无法核验历史覆盖。") }
            case "turn_context":
                let contextTurn = nonempty(p["turn_id"])
                if contextTurn != requestTimer.turnID { requestTimer.reset(at: timestamp, turn: contextTurn) }
                else { requestTimer.observeBoundary(timestamp) }
                turn = p["turn_id"] as? String
                model = nonempty(p["model"]) ?? "Unknown model"
            case "response_item":
                let itemType = p["type"] as? String ?? ""
                if itemType == "message" {
                    if p["role"] as? String == "assistant" { requestTimer.observeOutput(timestamp) }
                    else if ["user", "developer", "system"].contains(p["role"] as? String ?? "") {
                        requestTimer.observeBoundary(timestamp)
                    }
                } else if itemType == "reasoning" || itemType.hasSuffix("_call") {
                    requestTimer.observeOutput(timestamp)
                } else if itemType.hasSuffix("_output") {
                    requestTimer.observeBoundary(timestamp)
                }
            case "event_msg" where p["type"] as? String == "token_count":
                guard let info = p["info"] as? [String: Any] else { return }
                let total = usage(info["total_token_usage"])
                let last = usage(info["last_token_usage"])
                if total != nil || last != nil,
                   lastTimingCounter == nil || lastTimingCounter?.total != total || lastTimingCounter?.last != last {
                    // A legacy notification closes pending output, but never gets
                    // a request estimate: its delta can represent several requests.
                    _ = requestTimer.finish(at: timestamp, output: last?.output ?? 0)
                    lastTimingCounter = (total, last)
                }
                if total != nil || last != nil {
                    frames.append(Frame(timestamp: timestamp, model: nonempty(p["model"]) ?? nonempty(info["model"]) ?? model,
                        turn: turn, cumulative: total, last: last, responseID: nonempty(p["response_id"]), owner: nil))
                }
            case "token_usage_record":
                let response = nonempty(p["response_id"])
                let last = usage(p["usage"])
                if response == nil || last == nil {
                    warn(.missingIdentity, "请求记录缺少 response_id 或有效用量，未作为独立请求统计。")
                }
                let requestTurn = nonempty(p["turn_id"])
                let owner = nonempty(p["thread_id"])
                let matchingTurn = requestTurn != nil && requestTurn == requestTimer.turnID
                if let estimate = requestTimer.finish(at: timestamp, output: last?.output ?? 0),
                   owner == id, let response, last != nil, matchingTurn {
                    if let prior = requestEstimates[response], prior != estimate { conflictingEstimates.insert(response) }
                    else { requestEstimates[response] = estimate }
                }
                if owner == nil { warn(.missingIdentity, "原生请求缺少 thread_id，无法核验所有权；该请求及对应通知未计入。") }
                frames.append(Frame(timestamp: timestamp,
                    model: nonempty(p["model"]) ?? (requestTurn == nil || requestTurn == turn ? model : "Unknown model"),
                    explicitModel: nonempty(p["model"]) != nil, turn: requestTurn ?? turn, cumulative: usage(p["thread_token_usage"]), last: last,
                    responseID: response, owner: owner, isNative: true, explicitTurn: requestTurn != nil))
            case "event_msg" where p["type"] as? String == "task_started":
                requestTimer.reset(at: timestamp, turn: nonempty(p["turn_id"]))
                lastTimingCounter = nil
                if let turnID = nonempty(p["turn_id"]), let timestamp {
                    if turnStarts[turnID] != nil { failedTurns.insert(turnID) }
                    turnStarts[turnID] = (timestamp, frames.count, invalid)
                }
            case "event_msg" where p["type"] as? String == "turn_aborted":
                requestTimer.reset()
                lastTimingCounter = nil
                if nonempty(p["turn_id"]) == nil { conflictingEstimates.formUnion(requestEstimates.keys) }
                if let turnID = nonempty(p["turn_id"]) { failedTurns.insert(turnID); turnStarts.removeValue(forKey: turnID) }
                else {
                    // Older abort events can lack identity. Do not assign that
                    // failure to a guessed Turn or retain earlier success claims.
                    failedTurns.formUnion(turnStarts.keys); failedTurns.formUnion(turns.map(\.id))
                    turnStarts.removeAll()
                }
            case "event_msg" where p["type"] as? String == "task_complete":
                requestTimer.reset()
                guard let turnID = nonempty(p["turn_id"]) else { break }
                if let error = p["error"], !(error is NSNull) { failedTurns.insert(turnID); turnStarts.removeValue(forKey: turnID); break }
                if turnStarts[turnID] == nil, let prior = turns.first(where: { $0.id == turnID }) {
                    var first: UInt64?
                    if let raw = p["time_to_first_token_ms"], !(raw is NSNull) {
                        guard let value = unsigned(raw), value <= UInt64(prior.duration) else { failedTurns.insert(turnID); break }
                        first = value
                    }
                    if timestamp != prior.completed || unsigned(p["duration_ms"]) != UInt64(prior.duration) ||
                        first != prior.firstToken.map(UInt64.init) { failedTurns.insert(turnID) }
                    break
                }
                guard let duration = unsigned(p["duration_ms"]), duration > 0, duration <= UInt64(Int64.max) else {
                    failedTurns.insert(turnID); turnStarts.removeValue(forKey: turnID); break
                }
                var firstToken: Int64?
                if let raw = p["time_to_first_token_ms"], !(raw is NSNull) {
                    guard let value = unsigned(raw), value <= duration else {
                        failedTurns.insert(turnID); turnStarts.removeValue(forKey: turnID); break
                    }
                    firstToken = Int64(value)
                }
                guard let start = turnStarts.removeValue(forKey: turnID), !failedTurns.contains(turnID) else { break }
                guard let timestamp, timestamp >= start.date else { failedTurns.insert(turnID); break }
                let interval = Array(frames.dropFirst(start.frame))
                let native = interval.filter(\.isNative)
                let responses = Set(native.compactMap(\.responseID))
                // Event timestamps establish coverage, not elapsed time. Elapsed time
                // comes only from the explicit monotonic duration_ms field.
                let complete = invalid == start.invalid && !native.isEmpty && native.allSatisfy {
                    $0.owner == id && $0.explicitTurn && $0.turn == turnID && $0.responseID != nil && $0.last != nil &&
                    $0.timestamp.map { $0 >= start.date && $0 <= timestamp } == true
                }
                guard native.contains(where: { $0.owner == id && $0.explicitTurn && $0.turn == turnID && $0.last != nil &&
                    $0.timestamp.map { $0 >= start.date && $0 <= timestamp } == true }) else { break }
                turns.append(TurnTiming(id: turnID, started: start.date, completed: timestamp,
                    duration: Int64(duration), firstToken: firstToken, responses: responses,
                    locallyComplete: complete, frameRange: start.frame..<frames.count))
            case "compacted":
                requestTimer.reset()
                if let response = nonempty(p["compaction_response_id"]) { compacted.insert(response) }
            case "turn.completed":
                if let last = usage(value["usage"] ?? p["usage"]) {
                    fallback.append(Frame(timestamp: timestamp, model: model, turn: turn,
                        cumulative: nil, last: last, responseID: nonempty(value["id"]), owner: nil, identityIsResponseID: false))
                }
            default: break
            }
        }
        if frames.isEmpty { frames = fallback }
        for i in frames.indices {
            if let response = frames[i].responseID, compacted.contains(response) {
                frames[i].isCompaction = true
                if !frames[i].explicitModel { frames[i].model = "Unknown model" }
            }
        }
        let sessionID = id ?? url.deletingPathExtension().lastPathComponent
        return ParsedLog(id: sessionID, recordedSessionID: id, cwd: cwd, project: cwd.isEmpty ? "未识别项目" : URL(fileURLWithPath: cwd).lastPathComponent,
            source: source, started: started, lastActivity: max(started, lastActivity), parentId: parent,
            isFork: isFork, hasHistoryBase: hasHistoryBase, history: history, physicalID: physicalIdentity(url, sessionID: sessionID), path: url.path, boundaries: boundaries, incomplete: incomplete, frames: frames, invalidLines: invalid, invalidLineOffsets: invalidLineOffsets,
            diagnostics: Array(diagnostics), fileName: url.lastPathComponent, archived: url.path.contains("/archived_sessions/"), turns: turns.filter { !failedTurns.contains($0.id) }, failedTurns: failedTurns, requestEstimates: requestEstimates, conflictingEstimates: conflictingEstimates)
    }

    func unsigned(_ raw: Any?) -> UInt64? {
        guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return UInt64(number.stringValue)
    }
    func physicalIdentity(_ url: URL, sessionID: String) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let suffix = String(stem.suffix(36))
        // Codex filenames end in the immutable rollout UUID, after an optional
        // stable-thread_UUID underscore. Do not use SessionMeta.id after revert.
        return stem.hasPrefix("rollout-") && UUID(uuidString: suffix) != nil ? suffix : sessionID
    }
    func attachTurnPerformance(to sessions: inout [SessionUsage], logs: [ParsedLog], conflicting: Set<String>) {
        for index in sessions.indices {
            let sessionID = sessions[index].id
            let copies = logs.filter { $0.recordedSessionID == sessionID }
            let candidates = Dictionary(grouping: copies.flatMap { log in log.turns.map { (log, $0) } }, by: { $0.1.id })
            let rows = sessions[index].records
            for (turnID, entries) in candidates {
                guard !copies.contains(where: { $0.failedTurns.contains(turnID) }) else { continue }
                let timing = entries[0].1
                // Contradictory complete timers cannot be resolved by choosing a copy.
                guard entries.allSatisfy({ $0.1.started == timing.started && $0.1.completed == timing.completed &&
                    $0.1.duration == timing.duration && $0.1.firstToken == timing.firstToken }) else { continue }
                let turnRows = rows.filter { $0.turnID == turnID }
                guard turnRows.contains(where: { $0.evidence == .responseRecord }) else { continue }
                let accepted = Set(turnRows.compactMap(\.requestID))
                let observed = copies.flatMap(\.frames).filter { $0.isNative && $0.owner == sessionID && $0.turn == turnID }
                // Excluded counters are still evidence of uncertain coverage. Check
                // every physical copy, including copies without lifecycle metadata.
                let countersCovered = copies.allSatisfy { log in
                    let paired = pairedNotifications(log, inherited: 0).counts
                    let ranges = entries.filter { $0.0.path == log.path }.map { $0.1.frameRange }
                    return log.frames.enumerated().allSatisfy { position, frame in
                        guard !frame.isNative else { return true }
                        let relevant = ranges.contains { $0.contains(position) } || frame.turn == turnID ||
                            (frame.timestamp.map { $0 >= timing.started && $0 <= timing.completed } ?? true)
                        return !relevant || paired.contains(position)
                    }
                }
                let fullCoverage = entries.contains { _, candidate in
                    return entries.allSatisfy { $0.1.locallyComplete } &&
                    copies.allSatisfy { !$0.incomplete && $0.invalidLines == 0 && !$0.hasHistoryBase } &&
                    candidate.responses == accepted && candidate.responses == Set(observed.compactMap(\.responseID)) &&
                    observed.allSatisfy { $0.explicitTurn && $0.responseID != nil && $0.last != nil && $0.responseID.map { !conflicting.contains($0) } == true } &&
                    turnRows.allSatisfy { $0.evidence == .responseRecord } &&
                    !copies.flatMap(\.frames).contains { $0.isNative && $0.turn == turnID && $0.owner != sessionID } &&
                    !copies.flatMap(\.frames).contains { frame in
                        frame.isNative && !frame.explicitTurn &&
                        (frame.timestamp.map { $0 >= timing.started && $0 <= timing.completed } ?? true)
                    } &&
                    countersCovered
                }
                let performance = TurnPerformance(durationMilliseconds: timing.duration,
                    firstTokenMilliseconds: timing.firstToken,
                    outputTokens: fullCoverage ? turnRows.reduce(Int64(0)) { $0 + $1.usage.output } : nil,
                    responseCount: fullCoverage ? accepted.count : nil)
                let explicitMembers = Set(observed.filter(\.explicitTurn).compactMap(\.responseID))
                for row in sessions[index].records.indices where sessions[index].records[row].turnID == turnID &&
                    sessions[index].records[row].evidence == .responseRecord &&
                    sessions[index].records[row].requestID.map({ explicitMembers.contains($0) }) == true {
                    sessions[index].records[row].turnPerformance = performance
                }
            }
        }
    }

    func attachRequestEstimates(to sessions: inout [SessionUsage], logs: [ParsedLog]) {
        for index in sessions.indices {
            let copies = logs.filter { $0.recordedSessionID == sessions[index].id }
            let estimates = copies.flatMap { $0.requestEstimates.map { ($0.key, $0.value) } }
            let candidates = Dictionary(grouping: estimates, by: { $0.0 })
            for row in sessions[index].records.indices {
                let record = sessions[index].records[row]
                guard record.evidence == .responseRecord, !record.isCompaction,
                      let response = record.requestID, let entries = candidates[response],
                      !copies.contains(where: { log in log.conflictingEstimates.contains(response) ||
                          record.turnID.map { log.failedTurns.contains($0) } == true }) else { continue }
                let estimate = entries[0].1
                guard entries.allSatisfy({ $0.1 == estimate }) else { continue }
                sessions[index].records[row].requestEstimate = estimate
            }
        }
    }

    func sameResponse(_ a: Frame, _ b: Frame) -> Bool {
        a.owner == b.owner && a.last == b.last && a.model == b.model && a.turn == b.turn &&
            a.timestamp == b.timestamp && a.isCompaction == b.isCompaction
    }
    func normalizeCompaction(_ logs: inout [ParsedLog]) {
        let owned = logs.flatMap { log in log.frames.filter { $0.isNative && $0.owner == log.id } }
        let compacted = Set(owned.filter(\.isCompaction).compactMap(\.responseID))
        var explicitModels: [String: Set<String>] = [:]
        for frame in owned where frame.explicitModel {
            if let response = frame.responseID { explicitModels[response, default: []].insert(frame.model) }
        }
        // A retained prefix can precede the later marker. Absence of that marker
        // is not contrary evidence; explicit payload models remain authoritative.
        for i in logs.indices {
            for j in logs[i].frames.indices {
                let frame = logs[i].frames[j]
                guard frame.isNative, frame.owner == logs[i].id, let response = frame.responseID,
                      compacted.contains(response) else { continue }
                logs[i].frames[j].isCompaction = true
                if let models = explicitModels[response], models.count == 1 {
                    logs[i].frames[j].model = models.first!
                } else if !frame.explicitModel { logs[i].frames[j].model = "Unknown model" }
            }
        }
    }
    func accountingCopy(_ a: ParsedLog, _ b: ParsedLog) -> Bool {
        guard !a.frames.isEmpty, !b.frames.isEmpty, a.invalidLines == 0, b.invalidLines == 0,
              !a.incomplete, !b.incomplete, a.recordedSessionID == b.recordedSessionID,
              a.parentId == b.parentId, a.isFork == b.isFork, a.history == b.history else { return false }
        let shorter = a.frames.count <= b.frames.count ? a.frames : b.frames
        let longer = a.frames.count <= b.frames.count ? b.frames : a.frames
        return Array(longer.prefix(shorter.count)) == shorter
    }
    func pairedNotifications(_ log: ParsedLog, inherited: Int) -> (counts: Set<Int>, prior: Set<Int>) {
        var counts = Set<Int>(), prior = Set<Int>(), responses = Set<String>()
        for i in log.frames.indices where i >= inherited {
            let record = log.frames[i]
            guard record.isNative else { continue }
            // A malformed owned request may still have an independently valid legacy
            // counter. Foreign/unknown rejected records retain provenance for pairing.
            if record.owner == log.id && (record.responseID == nil || record.last == nil) { continue }
            if let response = record.responseID, !responses.insert(response).inserted { continue }
            func matches(_ j: Int) -> Bool {
                let count = log.frames[j]
                return !count.isNative && count.owner == nil && count.turn == record.turn &&
                    ((count.last != nil && count.last == record.last) ||
                     (!record.isCompaction && record.cumulative != nil && count.cumulative == record.cumulative))
            }
            if i + 1 < log.frames.count, matches(i + 1) { counts.insert(i + 1) }
            else if i > inherited, matches(i - 1) { counts.insert(i - 1); prior.insert(i) }
        }
        return (counts, prior)
    }
    func nativeOnlyAccounting(_ log: ParsedLog) -> Bool {
        let covered = pairedNotifications(log, inherited: 0).counts
        return !log.frames.isEmpty && log.frames.enumerated().allSatisfy {
            $0.element.isNative || covered.contains($0.offset)
        }
    }
    func historyDiagnostics(_ logs: [ParsedLog]) -> [ScanDiagnostic] {
        let physical = Dictionary(grouping: logs, by: \.physicalID)
        var result: [ScanDiagnostic] = []
        for log in logs where log.history != nil {
            var current = log
            var visited = Set<String>()
            var failure: String?
            while let reference = current.history {
                if reference.endByteOffset == 0 && reference.endOrdinal == 0 { break }
                guard visited.insert(current.physicalID).inserted else { failure = "引用形成循环"; break }
                guard let candidates = physical[reference.rolloutID] else { failure = "引用的物理日志不在本地扫描范围内"; break }
                // The exclusive ordinal is recorded by Codex, not a line count;
                // offsets must end on that exact complete JSONL record boundary.
                let matching = candidates.filter { $0.boundaries[reference.endByteOffset] == reference.endOrdinal }
                guard !matching.isEmpty else { failure = "引用的 byte/ordinal 边界无效、越界或文件已截断"; break }
                guard let target = matching.sorted(by: { $0.path < $1.path }).first(where: { candidate in
                    !candidate.invalidLineOffsets.contains(where: { $0 <= reference.endByteOffset }) &&
                        (!candidate.hasHistoryBase || candidate.history != nil)
                }) else { failure = "引用前缀损坏或 history_base 元数据无效，历史覆盖无法完整核验"; break }
                current = target
            }
            let resolvedMessage = log.history?.endByteOffset == 0 && log.history?.endOrdinal == 0 ?
                "history_base 声明空前缀；无需引入其他历史，仅统计本地记录。" :
                "history_base 已在本地核验；总量按独立用量计入，包括保留日志中的已回退历史。"
            result.append(.init(severity: failure == nil ? .information : .warning,
                kind: failure == nil ? .historyReference : .unresolvedHistoryReference,
                sessionID: log.id, fileName: log.fileName,
                message: "\(log.id.prefix(8))：" + (failure.map { "history_base \($0)；仅计入可核验的本地用量。" } ?? resolvedMessage)))
        }
        return result
    }

    func nonempty(_ raw: Any?) -> String? {
        guard let text = raw as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    /// A shared counter value alone is not evidence of replay. Require timestamps and
    /// model/turn identity as well. Rewritten legacy replay remains visibly unverified.
    func inheritedPrefix(child: ParsedLog, parent: ParsedLog?) -> Int {
        guard child.isFork, let parent, child.id != parent.id, let first = child.frames.first else { return 0 }
        var best = 0
        for start in parent.frames.indices where sameInherited(first, parent.frames[start]) {
            var count = 0
            while count < child.frames.count, start + count < parent.frames.count,
                  sameInherited(child.frames[count], parent.frames[start + count]) { count += 1 }
            best = max(best, count)
        }
        return best
    }
    func sameInherited(_ a: Frame, _ b: Frame) -> Bool {
        if let response = a.responseID { return response == b.responseID && a.owner == b.owner }
        return a.timestamp != nil && a.timestamp == b.timestamp && a.model == b.model && a.turn == b.turn &&
            a.cumulative != nil && a.cumulative == b.cumulative && a.last == b.last
    }

    func aggregate(_ log: ParsedLog, inherited: Int, seenResponses: inout Set<String>, countedUsage: inout TokenUsage, conflicting: Set<String>, allowLegacy: Bool, allowNative: Bool) ->
        (slices: [DailyModelUsage], diagnostics: [ScanDiagnostic], foreignRecords: Int, hours: [Date: TokenUsage], records: [UsageRecord]) {
        var sums: [DayModel: TokenUsage] = [:]
        var hours: [Date: TokenUsage] = [:]
        var records: [UsageRecord] = []
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var diagnostics = Set<ScanDiagnostic>()
        func warn(_ kind: DiagnosticKind, _ message: String) {
            diagnostics.insert(.init(severity: .warning, kind: kind, sessionID: log.id, fileName: log.fileName, message: "\(log.id.prefix(8))：\(message)"))
        }
        var previous: TokenUsage?
        var previousFrame: Frame?
        var lastOnlySignatures = Set<String>()
        var foreignRecords = 0
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        // Pair a response record with the adjacent usage notification, using its
        // request components. Compaction can make thread_token_usage diverge from
        // token_count.total_token_usage permanently; they are separate counters.
        let paired = pairedNotifications(log, inherited: inherited)
        let coveredCounts = paired.counts
        let coveredPriorRecords = paired.prior
        var requestsSinceCounter = TokenUsage()
        var unverifiableNativeSinceCounter = false
        var observedSnapshots = Set<TokenUsage>()
        for (position, frame) in log.frames.enumerated() {
            if position < inherited {
                if let total = frame.cumulative { previous = total; previousFrame = frame }
                continue
            }
            var delta: TokenUsage?
            var usingLastRequest = false
            var initialSnapshot = false
            if frame.isNative {
                guard frame.owner == log.id else {
                    if frame.owner != nil { foreignRecords += 1 }
                    unverifiableNativeSinceCounter = true
                    continue
                }
                guard let response = frame.responseID, frame.last != nil else { continue }
                if conflicting.contains(response) { unverifiableNativeSinceCounter = true; continue }
                guard allowNative, seenResponses.insert(response).inserted else { continue }
                delta = frame.last
            } else if let total = frame.cumulative {
                guard allowLegacy else { continue }
                if coveredCounts.contains(position) {
                    observedSnapshots.insert(total)
                    previous = total
                    previousFrame = frame
                    requestsSinceCounter = TokenUsage()
                    unverifiableNativeSinceCounter = false
                    continue
                }
                if unverifiableNativeSinceCounter {
                    previous = total; previousFrame = frame
                    requestsSinceCounter = TokenUsage(); unverifiableNativeSinceCounter = false
                    warn(.counterAmbiguity, "累计通知含有无法核验归属或冲突的原生请求，未用累计值重新计入；统计可能不完整。")
                    continue
                }
                if total == previous { continue }
                if !observedSnapshots.insert(total).inserted {
                    warn(.counterAmbiguity, "再次出现旧累计快照：已保守去重；无请求 ID 时无法区分相同数值的重置。")
                    continue
                }
                if let previous {
                    if let difference = total.difference(from: previous) {
                        delta = difference
                        if let last = frame.last, difference != last,
                           (frame.model != previousFrame?.model || frame.timestamp.map { formatter.string(from: $0) } != previousFrame?.timestamp.map { formatter.string(from: $0) }) {
                            delta = last
                            usingLastRequest = true
                            warn(.counterAmbiguity, "累计增量跨模型或日期且缺少中间请求，仅计入可确认的 last_token_usage。")
                        }
                    } else {
                        delta = frame.last
                        usingLastRequest = true
                        warn(.counterAmbiguity, "累计计数器回退：仅使用最近请求；无 last_token_usage 时跳过并重新建立基线。")
                    }
                } else if let last = frame.last, total != last {
                    delta = last
                    usingLastRequest = true
                    warn(.counterAmbiguity, "首个累计快照包含未观察到的历史，仅统计最近请求，未将历史归到当前模型或日期。")
                } else if log.hasHistoryBase || log.isFork {
                    delta = frame.last
                    usingLastRequest = true
                    if delta == nil { warn(.counterAmbiguity, "缺少历史基线，首个累计快照未纳入统计。") }
                } else { delta = total; initialSnapshot = true }
                if !usingLastRequest, !requestsSinceCounter.isZero, let value = delta {
                    if let remainder = value.difference(from: requestsSinceCounter) { delta = remainder }
                    else {
                        delta = nil
                        warn(.counterAmbiguity, "请求记录与累计通知无法核对，仅统计独立请求，跳过可能重复的累计通知。")
                    }
                }
                requestsSinceCounter = TokenUsage()
                previous = total
                previousFrame = frame
            } else if let last = frame.last {
                guard allowLegacy else { continue }
                if coveredCounts.contains(position) { requestsSinceCounter = TokenUsage(); unverifiableNativeSinceCounter = false; continue }
                if unverifiableNativeSinceCounter {
                    unverifiableNativeSinceCounter = false
                    warn(.counterAmbiguity, "最近用量通知与无法核验的原生请求重叠，未重新计入；统计可能不完整。")
                    continue
                }
                // Without a request identity an identical usage value might be either
                // a retransmission or a new request. Conservatively suppress repeated
                // equal values within one turn and disclose that ambiguity.
                let signature = frame.responseID ?? "\(frame.turn ?? "no-turn")|\(frame.model)|\(last.input)|\(last.cachedInput)|\(last.output)|\(last.reasoning)"
                if !lastOnlySignatures.insert(signature).inserted {
                    warn(.counterAmbiguity, "无累计快照/请求 ID 的相同用量无法区分重发，已保守去重，可能少计。")
                    continue
                }
                delta = last
            }
            guard let usage = delta, !usage.isZero else { continue }
            guard let date = frame.timestamp else {
                warn(.missingTimestamp, "用量事件缺少有效时间，未分配到文件修改日期，已跳过。")
                continue
            }
            guard usage.total <= Int64.max - countedUsage.total else {
                warn(.overflow, "Token 汇总超出 Int64 范围，跳过异常记录；统计不完整。")
                continue
            }
            countedUsage += usage
            if frame.owner == log.id, !frame.isCompaction, !coveredPriorRecords.contains(position) {
                requestsSinceCounter += usage
            }
            let key = DayModel(day: formatter.string(from: date), model: frame.model)
            sums[key, default: TokenUsage()] += usage
            let evidence: UsageEvidence
            if frame.owner == log.id && frame.responseID != nil { evidence = .responseRecord }
            else if usingLastRequest || frame.cumulative == nil || usage == frame.last { evidence = .lastUsage }
            else { evidence = initialSnapshot ? .initialSnapshot : .cumulativeDelta }
            records.append(UsageRecord(id: "\(log.path)#\(position)", sessionID: log.id, recordedSessionID: log.recordedSessionID, project: log.project,
                source: log.source, fileName: log.fileName, timestamp: date, day: key.day, model: frame.model,
                requestID: frame.identityIsResponseID ? frame.responseID : nil, turnID: frame.turn, usage: usage, evidence: evidence,
                isCompaction: frame.isCompaction, cumulativeSnapshot: frame.cumulative, lastReportedUsage: frame.last))
            if let hour = calendar.dateInterval(of: .hour, for: date)?.start {
                hours[hour, default: TokenUsage()] += usage
            } else {
                warn(.invalidTimeBucket, "无法确定事件的本地小时，小时趋势不完整；日汇总保留该用量。")
            }
        }
        return (sums.map { DailyModelUsage(day: $0.key.day, model: $0.key.model, usage: $0.value) }
            .sorted { ($0.day, $0.model) < ($1.day, $1.model) }, Array(diagnostics), foreignRecords, hours, records)
    }

    func forEachLine(_ url: URL, callback: (Data, Bool, Int64) -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var pending = Data()
        var offset: Int64 = 0
        while let chunk = try autoreleasepool(invoking: { try handle.read(upToCount: 64 * 1024) }), !chunk.isEmpty {
            var start = chunk.startIndex
            while start < chunk.endIndex, let end = chunk[start...].firstIndex(of: 10) {
                pending.append(chunk[start..<end])
                offset += Int64(pending.count) + 1
                if !pending.isEmpty { autoreleasepool { callback(pending, true, offset) } }
                pending.removeAll(keepingCapacity: true)
                start = chunk.index(after: end)
            }
            if start < chunk.endIndex { pending.append(chunk[start...]) }
        }
        if !pending.isEmpty { autoreleasepool { callback(pending, false, offset + Int64(pending.count)) } }
    }
}
