import Foundation

public struct OverviewSummary: Sendable {
    public let usage: TokenUsage
    public let models: [ModelUsage]
    public let dailyTotals: [(day: String, usage: TokenUsage)]
    public let hourlyTotals: [HourlyUsage]
    public let dailyRecordCounts: [String: Int]
    public let hourlyRecordCounts: [Date: Int]
    public let recordCount: Int
    /// Counts for the selected range before applying the model filter.
    public let modelRecordCounts: [String: Int]
}

/// Accepted-report projections only; no record arrays or price calculations in a query.
public struct OverviewIndex: Sendable {
    private struct DayKey: Hashable, Sendable { let session: String; let day: String; let model: String }
    private struct CountKey: Hashable, Sendable { let day: String; let model: String }
    private struct HourKey: Hashable, Sendable { let hour: Date; let model: String }
    private var days: [DayKey: TokenUsage] = [:]
    private var counts: [CountKey: Int] = [:]
    private var hourCounts: [HourKey: Int] = [:]
    private var hours: [HourKey: TokenUsage] = [:]
    public let observedModels: [String]

    public init(report: ScanReport, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var observed: Set<String> = []
        for session in report.sessions {
            for item in session.dailyModel {
                days[DayKey(session: session.id, day: item.day, model: item.model), default: TokenUsage()] += item.usage
            }
            for record in session.records {
                observed.insert(record.model)
                counts[CountKey(day: record.day, model: record.model), default: 0] += 1
                if let hour = calendar.dateInterval(of: .hour, for: record.timestamp)?.start {
                    hours[HourKey(hour: hour, model: record.model), default: TokenUsage()] += record.usage
                    hourCounts[HourKey(hour: hour, model: record.model), default: 0] += 1
                }
            }
        }
        observedModels = observed.sorted()
    }

    public func summary(in period: UsagePeriod, model: String? = nil, now: Date = Date(), timeZone: TimeZone = .current) -> OverviewSummary {
        let bounds = period.bounds(now: now, timeZone: timeZone)
        var usage = TokenUsage()
        var modelSums: [String: TokenUsage] = [:]
        var modelSessions: [String: Set<String>] = [:]
        var daily: [String: TokenUsage] = [:]
        var modelCounts: [String: Int] = [:]
        var dailyCounts: [String: Int] = [:]
        var hourlyCounts: [Date: Int] = [:]
        for (key, count) in counts where bounds.includes(key.day) && (model == nil || key.model == model) {
            dailyCounts[key.day, default: 0] += count
        }
        for (key, count) in counts where bounds.includes(key.day) { modelCounts[key.model, default: 0] += count }
        for (key, value) in days where bounds.includes(key.day) && (model == nil || key.model == model) {
            usage += value
            modelSums[key.model, default: TokenUsage()] += value
            modelSessions[key.model, default: []].insert(key.session)
            daily[key.day, default: TokenUsage()] += value
        }
        var hourly: [HourlyUsage] = []
        if period == .today {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            if let interval = calendar.dateInterval(of: .day, for: now) {
                for (key, count) in hourCounts where key.hour >= interval.start && key.hour < interval.end && (model == nil || key.model == model) {
                    hourlyCounts[key.hour, default: 0] += count
                }
                var sums: [Date: TokenUsage] = [:]
                for (key, value) in hours where key.hour >= interval.start && key.hour < interval.end && (model == nil || key.model == model) {
                    sums[key.hour, default: TokenUsage()] += value
                }
                var hour = interval.start
                while hour < interval.end {
                    hourly.append(HourlyUsage(hour: hour, usage: sums[hour] ?? TokenUsage()))
                    guard let next = calendar.date(byAdding: .hour, value: 1, to: hour), next > hour else { break }
                    hour = next
                }
            }
        }
        return OverviewSummary(usage: usage, models: modelSums.map {
            ModelUsage(model: $0.key, usage: $0.value, sessionCount: modelSessions[$0.key]?.count ?? 0)
        }.sorted { $0.usage.total == $1.usage.total ? $0.model < $1.model : $0.usage.total > $1.usage.total },
            dailyTotals: daily.map { ($0.key, $0.value) }.sorted { $0.day < $1.day }, hourlyTotals: hourly,
            dailyRecordCounts: dailyCounts, hourlyRecordCounts: hourlyCounts,
            recordCount: model.map { modelCounts[$0] ?? 0 } ?? modelCounts.values.reduce(0, +), modelRecordCounts: modelCounts)
    }
}
