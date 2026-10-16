#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import Charts
import AppKit

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "总览"
    case requests = "请求日志"
    case sessions = "历史会话"
    case settings = "设置"
    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .requests: return "list.bullet.rectangle"
        case .sessions: return "rectangle.stack"
        case .settings: return "gearshape"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: UsageStore
    @ViewState(initialValue: DashboardSection.overview) private var section: DashboardSection
    @ViewState(initialValue: false) private var showingStatus: Bool
    @ViewState(initialValue: "") private var overviewModel: String
    @ViewState(initialValue: "") private var requestModel: String
    private let initialRequestSelection: String?
    private let initialTrendMetric: OverviewTrendMetric
    private let initialPriceManagement: Bool
    init(initialSection: DashboardSection = .overview, initialRequestSelection: String? = nil, initialPriceManagement: Bool = false, initialOverviewModel: String = "", initialTrendMetric: OverviewTrendMetric = .tokens) {
        self._section = ViewState(initialValue: initialSection)
        self._overviewModel = ViewState(initialValue: initialOverviewModel)
        self.initialRequestSelection = initialRequestSelection
        self.initialPriceManagement = initialPriceManagement
        self.initialTrendMetric = initialTrendMetric
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                if store.hasReport {
                    statusLine
                    Divider()
                }
                Group {
                    if section != .settings && !store.hasReport {
                        PendingUsageView(loading: store.loading, error: store.errorMessage)
                    } else {
                        switch section {
                        case .overview:
                            OverviewContent(period: store.period, model: overviewModel.isEmpty ? nil : overviewModel, initialMetric: initialTrendMetric) {
                                requestModel = overviewModel
                                section = .requests
                            }
                        case .requests: RequestsContent(period: store.period, selectedRecordID: initialRequestSelection, initialModel: requestModel)
                        case .sessions: SessionsContent(period: store.period)
                        case .settings: SettingsContent(initialShowingPrices: initialPriceManagement)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(CPTheme.viewBackground)
        }
        .frame(minWidth: 950, minHeight: 630)
        .background(CPTheme.viewBackground)
        .sheet(isPresented: $showingStatus) {
            ScanStatusDetails().environmentObject(store).environment(\.appPalette, store.palette)
        }
        .environment(\.appPalette, store.palette)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                CPLogo(size: 28)
                Text("Codex Stats").font(.system(size: 14, weight: .semibold))
            }
            .padding(.bottom, 28)
            ForEach(DashboardSection.allCases) { item in
                Button { section = item } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 20)
                        Text(item.rawValue).font(.system(size: 12, weight: section == item ? .semibold : .medium))
                        Spacer()
                    }
                    .foregroundStyle(section == item ? AnyShapeStyle(CPTheme.accent) : AnyShapeStyle(Color.primary.opacity(0.70)))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(section == item ? AnyShapeStyle(CPTheme.selection) : AnyShapeStyle(Color.clear),
                                in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 3)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(store.scanStatus.requiresAttention ? CPTheme.orange : CPTheme.accent)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.scanStatus.sidebarText)
                        .font(.system(size: 11, weight: .medium))
                    Text(store.hasReport ? "\(store.report.fileCount) 份日志" : "等待扫描结果")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CPTheme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            QuitAppButton()
                .padding(.top, 14)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 24)
        .frame(width: 184, alignment: .leading)
        .background(CPTheme.sectionBackground)
    }

    private var statusLine: some View {
        let status = store.scanStatus
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.requiresAttention ? "exclamationmark.triangle" : "checkmark.circle")
                .foregroundStyle(status.requiresAttention ? CPTheme.orange : CPTheme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(status.summary).fontWeight(.medium)
                if let error = status.errorMessage {
                    Text(error).foregroundStyle(.secondary).lineLimit(2).help(error)
                }
            }
            Spacer(minLength: 8)
            Button("查看详情") { showingStatus = true }
                .accessibilityLabel("查看统计状态和诊断详情")
                .accessibilityIdentifier("scan-status-details")
        }
        .font(.system(size: 11))
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background((status.requiresAttention ? CPTheme.orange : CPTheme.accent).opacity(0.04))
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Label(section == .overview ? "用量统计" : section.rawValue, systemImage: section.icon)
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(store.loading ? "正在读取日志…" : (store.lastSuccessfulRefresh.map { "刷新于 \($0.formatted(date: .omitted, time: .standard))" } ?? "尚未成功刷新"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button { store.refresh() } label: {
                    Label("立即刷新", systemImage: "arrow.clockwise")
                }
                .disabled(store.loading)
                .buttonStyle(.bordered)
                Menu {
                    Button("手动刷新") { store.autoRefresh = false }
                    Divider()
                    ForEach(RefreshInterval.allCases) { interval in
                        Button("每 \(interval.label)") {
                            store.refreshInterval = interval
                            store.autoRefresh = true
                        }
                    }
                } label: {
                    Text(store.autoRefresh ? "自动刷新 \(store.refreshInterval.label)" : "手动刷新")
                }
                .fixedSize()
            }
            if section != .settings && section != .requests {
                HStack {
                    if section == .overview {
                        overviewModelPicker
                    } else {
                        Label("Codex · 本地会话日志", systemImage: "doc.text")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PeriodPicker(selection: $store.period)
                }
            }
        }
        .padding(.horizontal, section == .requests ? 16 : 24)
        .padding(.vertical, section == .requests || section == .overview ? 12 : 16)
        .background(CPTheme.headerBackground)
    }

    private var overviewModelPicker: some View {
        let summary = store.overviewSummary(model: overviewModel.isEmpty ? nil : overviewModel, in: store.period).data
        let models = Set(store.snapshot.overview.observedModels + (overviewModel.isEmpty ? [] : [overviewModel])).sorted {
            let firstCount = summary.modelRecordCounts[$0] ?? 0
            let secondCount = summary.modelRecordCounts[$1] ?? 0
            return firstCount == secondCount ? $0 < $1 : firstCount > secondCount
        }
        return Picker("模型", selection: $overviewModel) {
            Text("全部模型 · \(summary.modelRecordCounts.values.reduce(0, +)) 条记录").tag("")
            ForEach(models, id: \.self) { model in
                Text(model + " · \(summary.modelRecordCounts[model] ?? 0) 条记录").tag(model)
            }
        }
        .pickerStyle(.menu).frame(width: 264)
        .accessibilityIdentifier("overview-model-picker")
        .help((overviewModel.isEmpty ? "全部模型" : overviewModel) + "；按模型筛选本页全部指标，不会切换 Codex 实际使用的模型")
        .accessibilityValue(overviewModel.isEmpty ? "全部模型" : overviewModel)
    }

}

func trendDollarAxis(_ value: Double) -> String {
    "$" + value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.significantDigits(1...3)))
}

enum OverviewTrendMetric: String, CaseIterable, Identifiable {
    case tokens = "Token", records = "记录数", cost = "API 等值金额"
    var id: Self { self }
}

struct OverviewContent: View {
    @EnvironmentObject private var store: UsageStore
    let period: UsagePeriod
    var model: String? = nil
    var onViewRecords: () -> Void
    @ViewState(initialValue: OverviewTrendMetric.tokens) private var trendMetric: OverviewTrendMetric

    init(period: UsagePeriod, model: String? = nil, initialMetric: OverviewTrendMetric = .tokens, onViewRecords: @escaping () -> Void = {}) {
        self.period = period; self.model = model; self.onViewRecords = onViewRecords
        self._trendMetric = ViewState(initialValue: initialMetric)
    }

    var body: some View {
        let query = store.overviewSummary(model: model, in: period)
        let summary = query.data
        let usage = summary.usage
        let estimate = query.valuation.total
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    overviewCard("API 等值估算", value: estimate.state == .unavailable ? "无法估算" : dollars(estimate.amountUSD),
                                 caption: estimate.state == .partial ? "已估算小计" : "USD · 参考价值，非实际扣费", help: costHelp(estimate), compact: estimate.state == .unavailable) {
                        if estimate.state != .complete {
                            Text(abbreviated(estimate.unestimatedTokens) + " Token 未估算 · " + costReasons(estimate))
                                .foregroundStyle(CPTheme.orange)
                        }
                    }
                    overviewCard("总 Token", value: abbreviated(usage.total), caption: "输入 + 输出", help: detailedNumber(usage.total)) { EmptyView() }
                    overviewCard("缓存率", value: cacheRateLabel(usage), caption: "缓存输入 ÷ 输入", help: cacheRateHelp(usage), compact: CacheRate(usage: usage).state == .incomplete) { EmptyView() }
                    overviewCard("用量记录数", value: summary.recordCount.formatted(), caption: "已计入的记录，非确认请求数", help: "已接受的用量记录数量；累计快照可能包含多次请求") { EmptyView() }
                }
                .fixedSize(horizontal: false, vertical: true)
                Surface(padding: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("使用趋势 · \(period.rawValue)").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Picker("趋势指标", selection: $trendMetric) {
                                ForEach(OverviewTrendMetric.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented).labelsHidden().frame(width: 270)
                            .accessibilityIdentifier("overview-trend-metric")
                            .help("仅切换趋势：记录数为已接受用量记录；API 等值金额为参考价值，非实际扣费")
                        }
                        if summary.recordCount == 0 {
                            EmptyViewCard(title: "该筛选范围没有用量", subtitle: "可切换时间或返回全部模型；当前模型选择会保留。")
                        } else if trendMetric == .cost && estimate.state == .unavailable {
                            VStack(spacing: 10) {
                                Image(systemName: "chart.bar.xaxis").font(.system(size: 26)).foregroundStyle(CPTheme.orange)
                                Text("当前用量无法估算金额").font(.headline)
                                Text(costReasons(estimate) + "；可在设置中管理模型价格。")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity).frame(height: 168)
                        } else {
                            trendChart(summary, valuation: query.valuation)
                        }
                        if trendMetric == .cost {
                            Text("△ 已估算小计 · ◇ 未计价（不代表 $0）").font(.system(size: 10)).foregroundStyle(CPTheme.orange)
                            Text("USD · 参考价值，非实际扣费" + (estimate.state == .complete ? "" : " · △ 未完整估算：" + abbreviated(estimate.unestimatedTokens) + " Token 未估算 · " + costReasons(estimate)))
                                .font(.system(size: 10)).foregroundStyle(estimate.state == .complete ? AnyShapeStyle(.secondary) : AnyShapeStyle(CPTheme.orange))
                                .fixedSize(horizontal: false, vertical: true)
                        } else if trendMetric == .records {
                            Text("已接受的用量记录，非确认请求数").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Text(period == .today ? "按本地小时汇总 · 日志事件归属时间" : "按本地日期汇总 · 最多显示最近 30 个有记录的日期")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    Surface(padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("模型分布").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("按总 Token").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            if summary.models.isEmpty {
                                Text("当前筛选没有模型用量").font(.system(size: 11)).foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(summary.models.prefix(5))) { item in
                                    ModelBar(model: item, maxTokens: summary.models.first?.usage.total ?? 1, showSessionCount: false)
                                }
                            }
                            Button("查看用量记录", action: onViewRecords)
                                .accessibilityIdentifier("overview-view-records")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Surface(padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Token 明细").font(.system(size: 13, weight: .semibold))
                            TokenDetails(usage: usage, showTotal: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text("缓存包含在输入中，推理包含在输出中。所有统计遵循上方的模型与时间筛选；估算不代表订阅扣费。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(CPTheme.overviewBackground)
        .accessibilityIdentifier("overview-content")
    }

    private func overviewCard<Detail: View>(_ title: String, value: String, caption: String, help: String,
                                            compact: Bool = false, @ViewBuilder detail: () -> Detail) -> some View {
        Surface(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    if !compact {
                        Text(value).font(.system(size: 26, weight: .semibold)).fixedSize()
                    }
                    Text(value).font(.system(size: 17, weight: .semibold)).fixedSize()
                    Text(value).font(.system(size: 17, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                }
                .monospacedDigit().help(help)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title).accessibilityValue(value + "；" + help)
                Text(caption).foregroundStyle(.secondary)
                detail()
            }
            .font(.system(size: 10))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 98, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func trendValue(usage: TokenUsage, count: Int, cost: CostEstimate?) -> Double {
        switch trendMetric {
        case .tokens: return Double(usage.total)
        case .records: return Double(count)
        case .cost: return cost.map { NSDecimalNumber(decimal: $0.amountUSD).doubleValue } ?? 0
        }
    }

    @ChartContentBuilder private func trendMarks<X: Plottable>(x: PlottableValue<X>, value: Double, cost: CostEstimate?, showWords: Bool) -> some ChartContent {
        if trendMetric != .cost || cost?.state != .unavailable {
            BarMark(x: x, y: .value(trendMetric.rawValue, value))
                .foregroundStyle(CPTheme.accent).cornerRadius(3)
                .accessibilityLabel(trendMetric.rawValue)
                .accessibilityValue(trendMetric == .cost ? cost.map(costHelp) ?? "$0.00；无记录" : trendMetric == .records ? String(Int(value)) : abbreviated(value))
        }
        if trendMetric == .cost, let cost, cost.state != .complete {
            PointMark(x: x, y: .value("未完整估算", value))
                .symbol(cost.state == .unavailable ? .diamond : .triangle).symbolSize(36).foregroundStyle(CPTheme.orange)
                .annotation(position: .top) {
                    if showWords { Text(cost.state == .unavailable ? "未计价" : "小计").font(.system(size: 9)).foregroundStyle(CPTheme.orange).help(costHelp(cost)) }
                }
                .accessibilityLabel(cost.state == .unavailable ? "无法估算" : "已估算小计")
                .accessibilityValue(costHelp(cost))
        }
    }

    private func trendChart(_ summary: OverviewSummary, valuation: ValuationSummary) -> some View {
        Group {
            if period == .today {
                Chart(summary.hourlyTotals) { point in
                    trendMarks(x: .value("小时", point.hour, unit: .hour),
                               value: trendValue(usage: point.usage, count: summary.hourlyRecordCounts[point.hour] ?? 0, cost: valuation.hourly[point.hour]),
                               cost: valuation.hourly[point.hour], showWords: valuation.hourly.count <= 12)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisValueLabel(anchor: .top) {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                            }
                        }
                    }
                }
            } else {
                let days = Array(summary.dailyRecordCounts.keys.sorted().suffix(30))
                let usage = Dictionary(uniqueKeysWithValues: summary.dailyTotals.map { ($0.day, $0.usage) })
                let tickStep = max(1, Int(ceil(Double(max(0, days.count - 1)) / 5)))
                let ticks = days.enumerated().compactMap { $0.offset.isMultiple(of: tickStep) || $0.offset == days.count - 1 ? $0.element : nil }
                Chart(days, id: \.self) { day in
                    trendMarks(x: .value("日期", day),
                               value: trendValue(usage: usage[day] ?? TokenUsage(), count: summary.dailyRecordCounts[day] ?? 0, cost: valuation.daily[day]),
                               cost: valuation.daily[day], showWords: days.count <= 12)
                }
                .chartXAxis {
                    AxisMarks(values: ticks) { value in
                        AxisValueLabel(anchor: .top) {
                            if let day = value.as(String.self), ticks.contains(day) { Text(String(day.suffix(5))) }
                        }
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel(anchor: .trailing) {
                    if let amount = value.as(Double.self) {
                        if trendMetric == .cost { Text(trendDollarAxis(amount)) }
                        else if trendMetric == .records {
                            if amount.rounded() == amount { Text(amount.formatted(.number.precision(.fractionLength(0)))) }
                        } else { Text(abbreviated(amount)) }
                    }
                }
            }
        }
        .frame(height: 168)
    }

}

struct ScanStatusDetails: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("统计状态").font(.system(size: 17, weight: .semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(store.scanStatus.summary).fontWeight(.medium)
                    if let error = store.errorMessage {
                        Text(error).foregroundStyle(CPTheme.orange).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(store.lastSuccessfulRefresh.map { "上次成功扫描：\($0.formatted(date: .abbreviated, time: .standard))" } ?? "尚未成功扫描")
                    Text("\(store.report.fileCount) 份日志 · \(store.report.sessions.count) 个会话 · \(store.report.invalidLineCount) 行无效日志")
                    DiagnosticSummary(diagnostics: store.report.diagnostics, initiallyExpanded: true)
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("close-scan-status")
            }
        }
        .padding(24)
        .frame(width: 640, height: 420)
        .background(CPTheme.viewBackground)
    }
}
