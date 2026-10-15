import Foundation
import CoreFoundation

/// Codex reports cached input as a subset of input, and reasoning as a subset of output.
/// Therefore total tokens are input + output, not a sum of all four fields.
public struct TokenUsage: Hashable, Codable, Sendable {
    public var input: Int64
    public var cachedInput: Int64
    public var output: Int64
    public var reasoning: Int64
    public var cachedInputKnown: Bool
    public var reasoningKnown: Bool

    public init(input: Int64 = 0, cachedInput: Int64 = 0, output: Int64 = 0, reasoning: Int64 = 0, cachedInputKnown: Bool = true, reasoningKnown: Bool = true) {
        self.input = max(0, input)
        self.cachedInput = max(0, min(cachedInput, input))
        self.output = max(0, output)
        self.reasoning = max(0, min(reasoning, output))
        self.cachedInputKnown = cachedInputKnown
        self.reasoningKnown = reasoningKnown
    }

    public var total: Int64 { input + output }
    public var uncachedInput: Int64 { max(0, input - cachedInput) }
    public var isZero: Bool { input == 0 && output == 0 }

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(input: lhs.input + rhs.input,
                   cachedInput: lhs.cachedInput + rhs.cachedInput,
                   output: lhs.output + rhs.output,
                   reasoning: lhs.reasoning + rhs.reasoning,
                   cachedInputKnown: lhs.cachedInputKnown && rhs.cachedInputKnown,
                   reasoningKnown: lhs.reasoningKnown && rhs.reasoningKnown)
    }

    public static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs = lhs + rhs
    }

    /// Returns nil on a counter reset rather than silently creating a negative delta.
    public func difference(from previous: TokenUsage) -> TokenUsage? {
        guard input >= previous.input, output >= previous.output else { return nil }
        let cacheKnown = cachedInputKnown && previous.cachedInputKnown
        let reasonKnown = reasoningKnown && previous.reasoningKnown
        guard !cacheKnown || cachedInput >= previous.cachedInput,
              !reasonKnown || reasoning >= previous.reasoning else { return nil }
        return TokenUsage(input: input - previous.input,
                          cachedInput: cacheKnown ? cachedInput - previous.cachedInput : 0,
                          output: output - previous.output,
                          reasoning: reasonKnown ? reasoning - previous.reasoning : 0,
                          cachedInputKnown: cacheKnown, reasoningKnown: reasonKnown)
    }

    static func fromJSONObject(_ object: Any?) -> TokenUsage? {
        guard let values = object as? [String: Any] else { return nil }
        func integer(_ name: String, required: Bool = false) -> Int64? {
            guard let raw = values[name] else { return required ? nil : 0 }
            guard let n = raw as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
                  n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue < Double(Int64.max),
                  n.doubleValue.rounded(.towardZero) == n.doubleValue else { return nil }
            return n.int64Value
        }
        guard let input = integer("input_tokens", required: true),
              let output = integer("output_tokens", required: true),
              let cached = integer("cached_input_tokens"), let reasoning = integer("reasoning_output_tokens"),
              cached <= input, reasoning <= output, input <= Int64.max - output else { return nil }
        return TokenUsage(input: input, cachedInput: cached, output: output, reasoning: reasoning,
                          cachedInputKnown: values["cached_input_tokens"] != nil,
                          reasoningKnown: values["reasoning_output_tokens"] != nil)
    }
}

public struct DailyModelUsage: Hashable, Sendable {
    public let day: String // Local calendar date yyyy-MM-dd
    public let model: String
    public let usage: TokenUsage
    public init(day: String, model: String, usage: TokenUsage) {
        self.day = day
        self.model = model
        self.usage = usage
    }
}

public struct ModelUsage: Identifiable, Sendable {
    public let model: String
    public let usage: TokenUsage
    public let sessionCount: Int
    public var id: String { model }
}

public enum UsageEvidence: String, Codable, Sendable {
    case responseRecord, lastUsage, cumulativeDelta, initialSnapshot
    public var label: String {
        switch self {
        case .responseRecord: return "独立请求"
        case .lastUsage: return "最近一次用量"
        case .cumulativeDelta: return "累计增量"
        case .initialSnapshot: return "初始快照"
        }
    }
    public var explanation: String {
        switch self {
        case .responseRecord: return "使用日志中的独立 response_id 与请求用量；已去重对应的累计通知。"
        case .lastUsage: return "使用已记录的最近一次用量；没有请求 ID 时仍按原统计规则保守去重。"
        case .cumulativeDelta: return "累计快照的差额，必要时扣除已计入的独立请求。可能覆盖多次请求，无法进一步拆分。模型与时间取该用量事件的上下文。"
        case .initialSnapshot: return "日志首个可计入的累计快照，没有单次请求用量，可能包含多次请求；不作为已确认的单次请求。"
        }
    }
}

/// Timing belongs to the complete Turn, never to an individual response.
public struct TurnPerformance: Hashable, Codable, Sendable {
    public let durationMilliseconds: Int64
    public let firstTokenMilliseconds: Int64?
    /// Nil unless every owned response in this Turn has verified local coverage.
    public let outputTokens: Int64?
    public let responseCount: Int?
    public var averageOutputTokensPerSecond: Double? {
        outputTokens.map { Double($0) / (Double(durationMilliseconds) / 1000) }
    }
}

/// Event-order estimate including waiting before output, not measured generation time.
public struct RequestEstimate: Hashable, Codable, Sendable {
    public let startedAt: Date
    public let completedAt: Date
    public let durationMilliseconds: Int64
    public let outputTokens: Int64
    public var outputTokensPerSecond: Double? {
        guard outputTokens >= 200, durationMilliseconds >= 1000 else { return nil }
        return Double(outputTokens) / (Double(durationMilliseconds) / 1000)
    }
}

/// One accepted accounting entry. A cumulative entry need not represent one request.
public struct UsageRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String // Internal row identity, never presented as a request ID.
    public let sessionID: String
    public let recordedSessionID: String?
    public let project: String
    public let source: String
    public let fileName: String
    public let timestamp: Date
    public let day: String
    public let model: String
    public let requestID: String?
    public let turnID: String?
    public let usage: TokenUsage
    public let evidence: UsageEvidence
    public let isCompaction: Bool
    public let cumulativeSnapshot: TokenUsage?
    public let lastReportedUsage: TokenUsage?
    public var turnPerformance: TurnPerformance? = nil
    public var requestEstimate: RequestEstimate? = nil
}

public struct SessionUsage: Identifiable, Sendable {
    public let id: String
    public let project: String
    public let title: String
    public let workingDirectory: String
    public let source: String
    public let isFork: Bool
    public let replayDeduplicated: Bool
    public let replayUnverified: Bool
    public let firstActivity: Date
    public let lastActivity: Date
    public let dailyModel: [DailyModelUsage]
    public let fileName: String
    public var hourlyUsage: [Date: TokenUsage] = [:]
    public var records: [UsageRecord] = []

    public func usage(in period: UsagePeriod, now: Date = Date()) -> TokenUsage {
        usage(in: period.bounds(now: now))
    }

    func usage(in bounds: UsagePeriod.DayBounds) -> TokenUsage {
        dailyModel.filter { bounds.includes($0.day) }
            .reduce(TokenUsage()) { $0 + $1.usage }
    }

    public func modelUsage(in period: UsagePeriod, now: Date = Date()) -> [ModelUsage] {
        modelUsage(in: period.bounds(now: now))
    }

    func modelUsage(in bounds: UsagePeriod.DayBounds) -> [ModelUsage] {
        var models: [String: TokenUsage] = [:]
        for item in dailyModel where bounds.includes(item.day) {
            models[item.model, default: TokenUsage()] += item.usage
        }
        return models.map { ModelUsage(model: $0.key, usage: $0.value, sessionCount: 1) }
            .sorted { $0.usage.total > $1.usage.total }
    }
}

public enum UsagePeriod: String, CaseIterable, Identifiable, Sendable {
    case today = "今天"
    case sevenDays = "7 天"
    case thirtyDays = "30 天"
    case all = "全部"
    public var id: Self { self }

    struct DayBounds {
        let first: String?
        let last: String?
        func includes(_ day: String) -> Bool {
            guard let first, let last else { return true }
            return day >= first && day <= last
        }
    }

    func bounds(now: Date, timeZone: TimeZone = .current) -> DayBounds {
        guard self != .all else { return DayBounds(first: nil, last: nil) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let daysBack = self == .today ? 0 : (self == .sevenDays ? 6 : 29)
        guard let threshold = calendar.date(byAdding: .day, value: -daysBack, to: calendar.startOfDay(for: now)) else {
            return DayBounds(first: nil, last: nil)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return DayBounds(first: formatter.string(from: threshold), last: formatter.string(from: now))
    }

    public func includes(day: String, now: Date = Date()) -> Bool {
        bounds(now: now).includes(day)
    }

    public static func dateString(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: date)
    }
}

public enum DiagnosticSeverity: String, Codable, Sendable { case information, warning, error }
public enum DiagnosticKind: String, Codable, Sendable {
    case unreadableFile, invalidJSON, partialWrite, invalidUsage, incompleteFields
    case missingIdentity, missingTimestamp, counterAmbiguity, inheritedHistory
    case overflow, invalidTimeBucket, historyReference, unresolvedHistoryReference
    case supersededCopy, mergedPhysicalHistory, divergentAccountingCopies, conflictingResponse
}
public struct ScanDiagnostic: Hashable, Codable, Sendable {
    public let severity: DiagnosticSeverity
    public let kind: DiagnosticKind
    public let sessionID: String?
    public let fileName: String?
    public let message: String
    public init(severity: DiagnosticSeverity, kind: DiagnosticKind, sessionID: String? = nil,
                fileName: String? = nil, message: String) {
        self.severity = severity; self.kind = kind; self.sessionID = sessionID
        self.fileName = fileName; self.message = message
    }
}

public struct ScanReport: Sendable {
    public let sessions: [SessionUsage]
    public let fileCount: Int
    public let invalidLineCount: Int
    public let diagnostics: [ScanDiagnostic]
    public var warnings: [String] { diagnostics.filter { $0.severity != .information }.map(\.message) }
    public let refreshedAt: Date
    public var cachedFileCount: Int = 0

    public static let empty = ScanReport(sessions: [], fileCount: 0,
        invalidLineCount: 0, diagnostics: [], refreshedAt: Date())

    public func totals(in period: UsagePeriod, now: Date = Date()) -> TokenUsage {
        let bounds = period.bounds(now: now)
        return sessions.reduce(TokenUsage()) { $0 + $1.usage(in: bounds) }
    }

    public func models(in period: UsagePeriod, now: Date = Date()) -> [ModelUsage] {
        let bounds = period.bounds(now: now)
        var sums: [String: TokenUsage] = [:]
        var counts: [String: Int] = [:]
        for session in sessions {
            let details = session.modelUsage(in: bounds)
            for model in details {
                sums[model.model, default: TokenUsage()] += model.usage
                counts[model.model, default: 0] += 1
            }
        }
        return sums.map {
            ModelUsage(model: $0.key, usage: $0.value, sessionCount: counts[$0.key] ?? 0)
        }.sorted { $0.usage.total > $1.usage.total }
    }

    public func recentSessions(in period: UsagePeriod, now: Date = Date()) -> [SessionUsage] {
        let bounds = period.bounds(now: now)
        return sessions.filter { period == .all || !$0.usage(in: bounds).isZero || bounds.includes(UsagePeriod.dateString($0.lastActivity)) || bounds.includes(UsagePeriod.dateString($0.firstActivity)) }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    public func dailyTotals(in period: UsagePeriod, now: Date = Date()) -> [(day: String, usage: TokenUsage)] {
        let bounds = period.bounds(now: now)
        var sums: [String: TokenUsage] = [:]
        for session in sessions {
            for slice in session.dailyModel where bounds.includes(slice.day) {
                sums[slice.day, default: TokenUsage()] += slice.usage
            }
        }
        return sums.map { ($0.key, $0.value) }.sorted { $0.day < $1.day }
    }

    public func records(in period: UsagePeriod, now: Date = Date(), sortedByTime: Bool = true) -> [UsageRecord] {
        let bounds = period.bounds(now: now)
        let records = sessions.flatMap(\.records).filter { bounds.includes($0.day) }
        guard sortedByTime else { return records }
        return records.sorted { $0.timestamp == $1.timestamp ? $0.id < $1.id : $0.timestamp > $1.timestamp }
    }

    /// Local calendar hours, including empty hours; DST days can have 23 or 25 buckets.
    public func hourlyTotals(on day: Date = Date(), timeZone: TimeZone = .current) -> [HourlyUsage] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        var sums: [Date: TokenUsage] = [:]
        for session in sessions {
            for (hour, usage) in session.hourlyUsage where hour >= interval.start && hour < interval.end {
                sums[hour, default: TokenUsage()] += usage
            }
        }
        var result: [HourlyUsage] = []
        var hour = interval.start
        while hour < interval.end {
            result.append(HourlyUsage(hour: hour, usage: sums[hour] ?? TokenUsage()))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour), next > hour else { break }
            hour = next
        }
        return result
    }
}

public struct HourlyUsage: Identifiable, Sendable {
    public let hour: Date
    public let usage: TokenUsage
    public var id: Date { hour }
}
