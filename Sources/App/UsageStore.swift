#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import Foundation
import SwiftUI

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case seconds30 = 30, minute1 = 60, minutes5 = 300, minutes15 = 900
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .seconds30: return "30 秒"
        case .minute1: return "1 分钟"
        case .minutes5: return "5 分钟"
        case .minutes15: return "15 分钟"
        }
    }
}

struct ScanSnapshot {
    let report: ScanReport
    let valuation: ValuationIndex
    let overview: OverviewIndex
    let catalog: PriceCatalog?
    let observedModels: Set<String>
    init(report: ScanReport, catalog: PriceCatalog? = .builtIn, overview: OverviewIndex? = nil) {
        self.report = report; self.catalog = catalog
        valuation = ValuationIndex(report: report, catalog: catalog)
        self.overview = overview ?? OverviewIndex(report: report)
        observedModels = Set(self.overview.observedModels)
    }
}

private actor ScanWorker {
    private let scanner = CodexLogScanner()
    func scan(_ path: String) throws -> ScanReport { try scanner.scan(homePath: path) }
    func value(_ report: ScanReport, catalog: PriceCatalog?, overview: OverviewIndex?) -> ScanSnapshot { ScanSnapshot(report: report, catalog: catalog, overview: overview) }
    func load(_ file: PriceCatalogFile) throws -> PriceCatalog { try file.load() }
    func save(_ catalog: PriceCatalog, file: PriceCatalogFile) throws { try file.save(catalog) }
}

// One current query only; does not retain sessions or raw records.
final class UsageSummary {
    let usage: TokenUsage
    let models: [ModelUsage]
    let dailyTotals: [(day: String, usage: TokenUsage)]
    let hourlyTotals: [HourlyUsage]
    let valuation: ValuationSummary

    init(report: ScanReport, valuationIndex: ValuationIndex, period: UsagePeriod, now: Date) {
        valuation = valuationIndex.summary(in: period, now: now)
        usage = report.totals(in: period, now: now)
        models = report.models(in: period, now: now)
        dailyTotals = report.dailyTotals(in: period, now: now)
        hourlyTotals = period == .today ? report.hourlyTotals(on: now) : []
    }
}

final class OverviewUsageSummary {
    let data: OverviewSummary
    let valuation: ValuationSummary
    init(data: OverviewSummary, valuation: ValuationSummary) { self.data = data; self.valuation = valuation }
}

/// Shared dashboard wording, derived only from the accepted report and refresh state.
struct ScanStatus {
    let hasReport: Bool
    let loading: Bool
    let errorMessage: String?
    let warningCount: Int
    let informationCount: Int

    init(report: ScanReport, hasReport: Bool, loading: Bool, errorMessage: String?) {
        self.hasReport = hasReport
        self.loading = loading
        self.errorMessage = errorMessage
        warningCount = report.diagnostics.reduce(0) { $0 + ($1.severity == .information ? 0 : 1) }
        informationCount = report.diagnostics.count - warningCount
    }

    var requiresAttention: Bool { errorMessage != nil || warningCount > 0 }
    var summary: String {
        if errorMessage != nil { return hasReport ? "刷新失败，保留上次成功数据" : "读取失败" }
        if !hasReport { return loading ? "正在读取本地日志…" : "尚未取得用量" }
        if warningCount > 0 { return "\(warningCount) 条警告 / 错误 · 统计可能不完整" }
        return informationCount > 0 ? "统计状态正常 · \(informationCount) 条信息" : "统计状态正常"
    }
    var sidebarText: String {
        if errorMessage != nil { return hasReport ? "刷新失败，显示旧数据" : "读取失败" }
        if warningCount > 0 { return "统计可能不完整" }
        if loading { return "正在扫描…" }
        return hasReport ? "本地数据已连接" : "尚未读取"
    }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot = ScanSnapshot(report: .empty) {
        didSet { cachedSummary = nil; cachedOverview = nil; reportGeneration += 1 }
    }
    var report: ScanReport { snapshot.report }
    @Published private(set) var loading = false
    @Published private(set) var didScan = false
    @Published private(set) var lastSuccessfulRefresh: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var rootPath: String
    @Published private(set) var catalog: PriceCatalog?
    @Published private(set) var priceError: String?
    @Published private(set) var savingPrices = false
    var newBuiltInPrices: [ModelPrice] { catalog?.missingNewBuiltIns ?? [] }
    var priceCandidates: [String] { catalog?.candidates(observedModels: snapshot.observedModels) ?? [] }
    var canManagePrices: Bool { catalog != nil && !savingPrices }
    var canAddPrice: Bool { canManagePrices && hasReport && !priceCandidates.isEmpty }
    func deletePriceBlockReason(_ model: String) -> String? {
        if snapshot.observedModels.contains(model) { return "全部历史中仍有该模型的用量记录，不能删除价格" }
        if !hasReport || loading || errorMessage != nil || report.diagnostics.contains(where: { $0.severity != .information }) {
            return "尚不能确认全部历史中没有该模型；请先完成无警告的扫描"
        }
        if !canManagePrices { return "价格配置不可用或正在更新" }
        return nil
    }
    func estimate(_ record: UsageRecord) -> CostEstimate {
        .calculate(usage: record.usage, model: record.model, catalog: snapshot.catalog)
    }
    @Published var period: UsagePeriod = .today
    @Published var palette: AppPalette {
        didSet { defaults.set(palette.rawValue, forKey: "CodexStatsColorPalette") }
    }
    @Published var autoRefresh: Bool {
        didSet {
            defaults.set(autoRefresh, forKey: "CodexPulseAutoRefresh")
            configureTimer()
        }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: "CodexStatsRefreshIntervalSeconds")
            configureTimer()
        }
    }
    var hasReport: Bool { lastSuccessfulRefresh != nil }
    var scanStatus: ScanStatus {
        ScanStatus(report: report, hasReport: hasReport, loading: loading, errorMessage: errorMessage)
    }

    private let defaults: UserDefaults
    private let worker = ScanWorker()
    private let priceFile: PriceCatalogFile
    private var pricesLoaded = false
    private var timer: Timer?
    private var pendingRefresh = false
    private var reportGeneration = 0
    struct SummaryKey: Equatable {
        let generation: Int
        let period: UsagePeriod
        let model: String?
        let day: Date
        let timeZone: String
        let utcOffset: Int

        init(generation: Int, period: UsagePeriod, model: String? = nil, now: Date, timeZone: TimeZone) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            self.generation = generation
            self.period = period
            self.model = model
            day = calendar.startOfDay(for: now)
            self.timeZone = timeZone.identifier
            utcOffset = timeZone.secondsFromGMT(for: now)
        }
    }
    private var cachedSummary: (key: SummaryKey, value: UsageSummary)?

    private var cachedOverview: (key: SummaryKey, value: OverviewUsageSummary)?

    func overviewSummary(model: String? = nil, in period: UsagePeriod, now: Date = Date()) -> OverviewUsageSummary {
        let timeZone = TimeZone.current
        let key = SummaryKey(generation: reportGeneration, period: period, model: model, now: now, timeZone: timeZone)
        if let cachedOverview, cachedOverview.key == key { return cachedOverview.value }
        let value = OverviewUsageSummary(data: snapshot.overview.summary(in: period, model: model, now: now, timeZone: timeZone),
                                        valuation: snapshot.valuation.summary(in: period, model: model, now: now, timeZone: timeZone))
        cachedOverview = (key, value)
        return value
    }

    var summary: UsageSummary { summary(in: period) }

    func summary(in period: UsagePeriod, now: Date = Date()) -> UsageSummary {
        let key = SummaryKey(generation: reportGeneration, period: period, now: now, timeZone: .current)
        if let cachedSummary, cachedSummary.key == key { return cachedSummary.value }
        let value = UsageSummary(report: report, valuationIndex: snapshot.valuation, period: period, now: now)
        cachedSummary = (key, value)
        return value
    }

    init(defaults: UserDefaults = .standard, priceFileURL: URL = PriceCatalogFile.defaultURL) {
        self.defaults = defaults
        priceFile = PriceCatalogFile(url: priceFileURL)
        palette = defaults.string(forKey: "CodexStatsColorPalette").flatMap(AppPalette.init(rawValue:)) ?? .cyan
        rootPath = defaults.string(forKey: "CodexPulseRoot")
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? NSString(string: "~/.codex").expandingTildeInPath
        autoRefresh = defaults.object(forKey: "CodexPulseAutoRefresh") as? Bool ?? true
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: "CodexStatsRefreshIntervalSeconds")) ?? .seconds30
        configureTimer()
        refresh()
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        if autoRefresh {
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval.rawValue), repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    func updateRoot(_ value: String) {
        let path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        rootPath = path
        snapshot = ScanSnapshot(report: .empty, catalog: catalog)
        lastSuccessfulRefresh = nil
        didScan = false
        errorMessage = nil
        defaults.set(path, forKey: "CodexPulseRoot")
        refresh()
    }

    func reloadPrices() async {
        guard !savingPrices else { return }
        do {
            let revision = catalog?.revision
            let loaded = try await worker.load(priceFile)
            guard !savingPrices, revision == catalog?.revision else { return }
            catalog = loaded
            pricesLoaded = true; priceError = nil
            if hasReport { await revalueCurrentReport() }
        } catch { priceError = error.localizedDescription }
    }

    /// Recheck after persistence/actor suspension; late scans never restore an old price revision.
    private func valued(_ report: ScanReport, overview: OverviewIndex? = nil) async -> ScanSnapshot {
        while true {
            let captured = catalog
            let result = await worker.value(report, catalog: captured, overview: overview)
            if captured?.revision == catalog?.revision { return result }
        }
    }
    private func revalueCurrentReport() async {
        while true {
            let generation = reportGeneration
            let result = await valued(report, overview: snapshot.overview)
            if generation == reportGeneration { snapshot = result; return }
        }
    }
    func savePrice(model: String, input: String, cachedInput: String, output: String, adding: Bool) async -> Bool {
        guard canManagePrices, let catalog else { priceError = "价格配置不可用或正在更新"; return false }
        if adding && (!canAddPrice || !priceCandidates.contains(model)) {
            priceError = "请选择全部历史中尚未配置价格的模型"; return false
        }
        if !adding && catalog.entry(for: model) == nil { priceError = "该价格记录已不存在"; return false }
        do {
            let entry = try ModelPrice(model: model, input: input, cachedInput: cachedInput, output: output)
            return await persist(try catalog.setting(entry))
        } catch { priceError = error.localizedDescription; return false }
    }
    func deletePrice(_ model: String) async -> Bool {
        guard let reason = deletePriceBlockReason(model) else {
            guard let catalog else { return false }
            do { return await persist(try catalog.removing(model)) }
            catch { priceError = error.localizedDescription; return false }
        }
        priceError = reason; return false
    }
    func addNewBuiltInPrices() async -> Bool {
        guard canManagePrices, let catalog, !catalog.missingNewBuiltIns.isEmpty else { return false }
        do { return await persist(try catalog.addingNewBuiltIns()) }
        catch { priceError = error.localizedDescription; return false }
    }
    private func persist(_ next: PriceCatalog) async -> Bool {
        savingPrices = true
        defer { savingPrices = false }
        do {
            try await worker.save(next, file: priceFile)
            catalog = next; pricesLoaded = true; priceError = nil
            await revalueCurrentReport()
            return true
        } catch { priceError = error.localizedDescription; return false }
    }

    func refresh() {
        guard !loading else { pendingRefresh = true; return }
        loading = true
        let path = rootPath
        Task {
            do {
                if !pricesLoaded { await reloadPrices() }
                let report = try await worker.scan(path)
                let scanned = await valued(report)
                if path == rootPath {
                    snapshot = scanned
                    lastSuccessfulRefresh = scanned.report.refreshedAt
                    didScan = true
                    errorMessage = nil
                }
            } catch {
                if path == rootPath { errorMessage = error.localizedDescription; didScan = true }
            }
            loading = false
            if pendingRefresh {
                pendingRefresh = false
                refresh()
            }
        }
    }
}
