import Foundation

/// A ratio of accepted input counters, never an average of group percentages.
public struct CacheRate: Encodable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case known, noInput, incomplete }
    public let state: State
    public let cachedInput: Int64
    public let input: Int64
    public var fraction: Double? { state == .known ? Double(cachedInput) / Double(input) : nil }

    public init(usage: TokenUsage) {
        input = usage.input
        cachedInput = usage.cachedInput
        state = input == 0 ? .noInput : usage.cachedInputKnown ? .known : .incomplete
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(state, forKey: .state)
        try box.encode(input, forKey: .input)
        if state == .incomplete { try box.encodeNil(forKey: .cachedInput) }
        else { try box.encode(cachedInput, forKey: .cachedInput) }
        try box.encode(fraction, forKey: .fraction)
    }
    private enum CodingKeys: String, CodingKey { case state, input, cachedInput, fraction }

}

public struct ReferencePrice: Equatable, Sendable {
    public let input: Decimal
    public let cachedInput: Decimal
    public let output: Decimal
    public init(input: Decimal, cachedInput: Decimal, output: Decimal) {
        self.input = input; self.cachedInput = cachedInput; self.output = output
    }
}

/// Versioned reference values, not a historical bill or a subscription balance.
public enum ReferencePricing {
    public static let version = "openai-standard-short-2026-10-15-r2"
    public static let verifiedOn = "2026-10-15"
    public static let source = "https://developers.openai.com/api/docs/pricing"
    public static let changelogSource = "https://developers.openai.com/api/docs/changelog"
    public static let newModels: Set<String> = ["gpt-5.6-sol", "gpt-6-sol"]
    public static func source(for model: String) -> String { model == "gpt-6-sol" ? changelogSource : source }
    public static let basis = "USD · Standard 短上下文参考价；所有历史统一按此快照折算，非实际扣费"
    public static let exclusions = "不含缓存写入单列费用、长上下文加价、Fast/Ultrafast、Batch/Flex、地域、税费及工具费用"
    public static let prices: [String: ReferencePrice] = [
        "gpt-6.1-sol": price("2", "0.10", "10"),
        "gpt-6-astra": price("10", "1", "50"),
        "gpt-6-luna": price("0.10", "0.01", "0.50"),
        "gpt-5.6-sol": price("4", "0.40", "20"),
        "gpt-6-sol": price("2", "0.20", "10"),
        "gpt-5.3-codex": price("1.75", "0.175", "14")
    ]
    private static func price(_ input: String, _ cached: String, _ output: String) -> ReferencePrice {
        ReferencePrice(input: Decimal(string: input, locale: Locale(identifier: "en_US_POSIX"))!,
                       cachedInput: Decimal(string: cached, locale: Locale(identifier: "en_US_POSIX"))!,
                       output: Decimal(string: output, locale: Locale(identifier: "en_US_POSIX"))!)
    }
}

public struct CostEstimate: Encodable, Equatable, Sendable {
    public enum State: String, Encodable, Sendable { case complete, partial, unavailable }
    public enum MissingReason: String, Codable, Sendable {
        case missingPrice, incompleteCachedInput, calculationFailure, priceConfigurationUnavailable
        public var label: String {
            switch self {
            case .priceConfigurationUnavailable: return "价格配置不可用"
            case .missingPrice: return "模型无参考价"
            case .incompleteCachedInput: return "缓存拆分未完整记录"
            case .calculationFailure: return "金额无法计算"
            }
        }
    }
    public private(set) var amountUSD: Decimal = 0
    public private(set) var estimatedTokens: Int64 = 0
    public private(set) var unestimatedTokens: Int64 = 0
    public private(set) var reasons: [MissingReason: Int] = [:]
    public private(set) var priceVersion: String
    public private(set) var priceSources: Set<ModelPrice.Source> = []
    public init(priceVersion: String = ReferencePricing.version) { self.priceVersion = priceVersion }
    public var state: State {
        unestimatedTokens == 0 ? .complete : estimatedTokens > 0 ? .partial : .unavailable
    }
    public var exactUSD: String { NSDecimalNumber(decimal: amountUSD).stringValue }

    public static func calculate(usage: TokenUsage, model: String) -> CostEstimate {
        calculate(usage: usage, model: model, catalog: .builtIn)
    }
    public static func calculate(usage: TokenUsage, model: String, catalog: PriceCatalog?) -> CostEstimate {
        guard let catalog else {
            var result = CostEstimate(priceVersion: "unavailable")
            if !usage.isZero { result.exclude(usage.total, reason: .priceConfigurationUnavailable) }
            return result
        }
        let entry = catalog.entry(for: model)
        var result = calculate(usage: usage, price: entry?.price)
        result.priceVersion = catalog.revision
        if let entry, result.estimatedTokens > 0 { result.priceSources.insert(entry.source) }
        return result
    }
    public static func calculate(usage: TokenUsage, price: ReferencePrice?) -> CostEstimate {
        var result = CostEstimate()
        guard !usage.isZero else { return result }
        guard let price else { result.exclude(usage.total, reason: .missingPrice); return result }
        guard usage.input == 0 || usage.cachedInputKnown else {
            result.exclude(usage.total, reason: .incompleteCachedInput); return result
        }
        do {
            let input = try decimalProduct(Decimal(usage.uncachedInput), price.input)
            let cached = try decimalProduct(Decimal(usage.cachedInput), price.cachedInput)
            let output = try decimalProduct(Decimal(usage.output), price.output)
            var subtotal = try decimalSum(try decimalSum(input, cached), output)
            var million = Decimal(1_000_000), amount = Decimal()
            guard NSDecimalDivide(&amount, &subtotal, &million, .plain) == .noError, !amount.isNaN, amount >= 0 else {
                throw ArithmeticFailure.invalid
            }
            result.amountUSD = amount
            result.estimatedTokens = usage.total
        } catch { result.exclude(usage.total, reason: .calculationFailure) }
        return result
    }
    private mutating func exclude(_ tokens: Int64, reason: MissingReason) {
        unestimatedTokens += tokens
        reasons[reason, default: 0] += 1
    }
    public mutating func merge(_ other: CostEstimate) {
        if estimatedTokens == 0 && unestimatedTokens == 0 { priceVersion = other.priceVersion }
        priceSources.formUnion(other.priceSources)
        estimatedTokens += other.estimatedTokens
        unestimatedTokens += other.unestimatedTokens
        for (reason, count) in other.reasons { reasons[reason, default: 0] += count }
        do { amountUSD = try decimalSum(amountUSD, other.amountUSD) }
        catch {
            unestimatedTokens += estimatedTokens; estimatedTokens = 0; amountUSD = 0
            reasons[.calculationFailure, default: 0] += 1
        }
    }
    public func encode(to encoder: Encoder) throws {
        var box = encoder.container(keyedBy: CodingKeys.self)
        try box.encode(state, forKey: .state)
        if state == .unavailable { try box.encodeNil(forKey: .amountUSD) }
        else { try box.encode(exactUSD, forKey: .amountUSD) }
        try box.encode("USD", forKey: .currency)
        try box.encode(priceVersion, forKey: .priceVersion)
        try box.encode(priceSources.map(\.rawValue).sorted(), forKey: .priceSources)
        try box.encode(estimatedTokens, forKey: .estimatedTokens)
        try box.encode(unestimatedTokens, forKey: .unestimatedTokens)
        try box.encode(Dictionary(uniqueKeysWithValues: reasons.map { ($0.key.rawValue, $0.value) }), forKey: .reasons)
    }
    private enum CodingKeys: String, CodingKey {
        case state, amountUSD, currency, priceVersion, priceSources, estimatedTokens, unestimatedTokens, reasons
    }
}

private enum ArithmeticFailure: Error { case invalid }
private func decimalProduct(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
    var a = lhs, b = rhs, result = Decimal()
    guard NSDecimalMultiply(&result, &a, &b, .plain) == .noError, !result.isNaN else { throw ArithmeticFailure.invalid }
    return result
}
private func decimalSum(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
    var a = lhs, b = rhs, result = Decimal()
    guard NSDecimalAdd(&result, &a, &b, .plain) == .noError, !result.isNaN else { throw ArithmeticFailure.invalid }
    return result
}

public struct ValuationSummary: Sendable {
    public var daily: [String: CostEstimate] = [:]
    public var hourly: [Date: CostEstimate] = [:]
    public var total = CostEstimate()
    public var models: [String: CostEstimate] = [:]
    public var sessions: [String: CostEstimate] = [:]
    public var sessionModels: [String: [String: CostEstimate]] = [:]
}

/// Scalar buckets only. Build once on ScanWorker; range changes merge buckets, never records.
public struct ValuationIndex: Sendable {
    private struct Key: Hashable, Sendable { let session: String; let day: String; let model: String }
    private struct HourKey: Hashable, Sendable { let hour: Date; let model: String }
    private var hours: [HourKey: CostEstimate] = [:]
    private var buckets: [Key: CostEstimate] = [:]
    public var bucketCount: Int { buckets.count }
    public let catalogRevision: String
    public init(report: ScanReport, catalog: PriceCatalog? = .builtIn, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        catalogRevision = catalog?.revision ?? "unavailable"
        for session in report.sessions {
            for record in session.records {
                let key = Key(session: session.id, day: record.day, model: record.model)
                let estimate = CostEstimate.calculate(usage: record.usage, model: record.model, catalog: catalog)
                buckets[key, default: CostEstimate(priceVersion: catalogRevision)].merge(estimate)
                if let hour = calendar.dateInterval(of: .hour, for: record.timestamp)?.start {
                    hours[HourKey(hour: hour, model: record.model), default: CostEstimate(priceVersion: catalogRevision)].merge(estimate)
                }
            }
        }
    }
    public func summary(in period: UsagePeriod, model: String? = nil, now: Date = Date(), timeZone: TimeZone = .current) -> ValuationSummary {
        let bounds = period.bounds(now: now, timeZone: timeZone)
        var result = ValuationSummary()
        result.total = CostEstimate(priceVersion: catalogRevision)
        for (key, estimate) in buckets where bounds.includes(key.day) && (model == nil || key.model == model) {
            result.total.merge(estimate)
            result.daily[key.day, default: CostEstimate(priceVersion: catalogRevision)].merge(estimate)
            result.models[key.model, default: CostEstimate()].merge(estimate)
            result.sessions[key.session, default: CostEstimate()].merge(estimate)
            result.sessionModels[key.session, default: [:]][key.model, default: CostEstimate()].merge(estimate)
        }
        if period == .today {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            if let interval = calendar.dateInterval(of: .day, for: now) {
                for (key, estimate) in hours where key.hour >= interval.start && key.hour < interval.end && (model == nil || key.model == model) {
                    result.hourly[key.hour, default: CostEstimate(priceVersion: catalogRevision)].merge(estimate)
                }
            }
        }
        return result
    }
}
