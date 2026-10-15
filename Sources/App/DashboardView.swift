#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import Charts
import AppKit

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "总览"
    case requests = "请求日志"
    case models = "模型统计"
    case sessions = "历史会话"
    case settings = "设置"
    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .requests: return "list.bullet.rectangle"
        case .models: return "cpu"
        case .sessions: return "rectangle.stack"
        case .settings: return "gearshape"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: UsageStore
    @ViewState(initialValue: DashboardSection.overview) private var section: DashboardSection
    private let initialRequestSelection: String?
    init(initialSection: DashboardSection = .overview, initialRequestSelection: String? = nil) {
        self._section = ViewState(initialValue: initialSection)
        self.initialRequestSelection = initialRequestSelection
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                Divider()
                Group {
                    if section != .settings && !store.hasReport {
                        PendingUsageView(loading: store.loading, error: store.errorMessage)
                    } else {
                        switch section {
                        case .overview: OverviewContent(period: store.period)
                        case .requests: RequestsContent(period: store.period, selectedRecordID: initialRequestSelection)
                        case .models: ModelsContent(period: store.period)
                        case .sessions: SessionsContent(period: store.period)
                        case .settings: SettingsContent()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(CPTheme.viewBackground)
        }
        .frame(minWidth: 950, minHeight: 630)
        .background(CPTheme.viewBackground)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                CPLogo(size: 39)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex Stats").font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("LOCAL ANALYTICS")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .tracking(1.15).foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 36)
            ForEach(DashboardSection.allCases) { item in
                Button { section = item } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 20)
                        Text(item.rawValue).font(.system(size: 12, weight: section == item ? .semibold : .medium))
                        Spacer()
                    }
                    .foregroundStyle(section == item ? CPTheme.accent : Color.primary.opacity(0.70))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(section == item ? CPTheme.accent.opacity(0.09) : .clear,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 3)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(store.errorMessage == nil ? CPTheme.accent : CPTheme.orange)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.loading ? "正在扫描…" : (store.errorMessage != nil ? "读取失败" : (store.hasReport ? "本地数据已连接" : "尚未读取")))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 27)
        .frame(width: 218, alignment: .leading)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var header: some View {
        VStack(spacing: 14) {
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
            if section != .settings {
                HStack {
                    Label("Codex · 本地会话日志", systemImage: "doc.text")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    PeriodPicker(selection: $store.period)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

}

private struct DailyPoint: Identifiable {
    let day: String
    let tokens: Double
    var id: String { day }
}

private struct OverviewContent: View {
    @EnvironmentObject private var store: UsageStore
    let period: UsagePeriod

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                let usage = store.report.totals(in: period)
                HStack(spacing: 12) {
                    MetricTile(label: "总 Token", number: usage.total, tint: CPTheme.accent, systemImage: "circle.hexagongrid")
                    MetricTile(label: "输入 Token", number: usage.input, tint: CPTheme.cyan, systemImage: "arrow.down.left")
                    MetricTile(label: "输出 Token", number: usage.output, tint: CPTheme.purple, systemImage: "arrow.up.right")
                    MetricTile(label: "缓存输入", number: usage.cachedInput, tint: CPTheme.accent, systemImage: "externaldrive", known: usage.cachedInputKnown)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("使用趋势 · \(period.rawValue)").font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Circle().fill(CPTheme.cyan).frame(width: 7, height: 7)
                            Text("Tokens").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        if usage.isZero {
                            EmptyViewCard(title: "该时间范围没有用量", subtitle: "检查日志位置，或选择其他时间范围。")
                        } else {
                            trendChart
                        }
                        Text(period == .today ? "按本地小时汇总，归属时间取已计入用量的日志事件时间" : "按本地日期汇总，最近最多显示 30 个有记录的日期")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    Surface {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("模型排行").font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text("按总 Token").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            let models = store.report.models(in: period)
                            if models.isEmpty {
                                EmptyViewCard(title: "暂无模型数据", subtitle: "请检查日志目录设置。")
                            } else {
                                ForEach(Array(models.prefix(5))) { model in
                                    ModelBar(model: model, maxTokens: models.first?.usage.total ?? 1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Token 明细").font(.system(size: 13, weight: .semibold))
                            TokenDetails(usage: usage)
                            Divider()
                            if usage.cachedInputKnown && usage.input > 0 {
                                Text("缓存占输入 \((Double(usage.cachedInput) / Double(usage.input)).formatted(.percent.precision(.fractionLength(1))))")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            Text("总计 = 输入 + 输出。缓存包含在输入中，推理包含在输出中。")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                            Text("本地日志统计，不代表订阅扣费。")
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let error = store.errorMessage { StatusBanner(message: error) }
                DiagnosticSummary(diagnostics: store.report.diagnostics)
            }
            .padding(24)
        }
    }

    private var trendChart: some View {
        Group {
            if period == .today {
                Chart(store.report.hourlyTotals()) { point in
                    BarMark(x: .value("小时", point.hour, unit: .hour), y: .value("Token", point.usage.total))
                        .foregroundStyle(CPTheme.cyan)
                        .cornerRadius(3)
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
                let points = Array(store.report.dailyTotals(in: period).suffix(30))
                    .map { DailyPoint(day: $0.day, tokens: Double($0.usage.total)) }
                Chart(points) { point in
                    BarMark(x: .value("日期", point.day), y: .value("Token", point.tokens))
                        .foregroundStyle(CPTheme.cyan)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(anchor: .top) {
                            if let day = value.as(String.self) { Text(String(day.suffix(5))) }
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
                    if let tokens = value.as(Double.self) {
                        Text(abbreviated(tokens))
                    }
                }
            }
        }
        .frame(height: 210)
    }
}

private struct ModelsContent: View {
    @EnvironmentObject private var store: UsageStore
    let period: UsagePeriod
    @ViewState(initialValue: "") private var search: String

    @ViewState(initialValue: ModelSort.total) private var sort: ModelSort
    private enum ModelSort: String, CaseIterable {
        case total = "总 Token", input = "输入", output = "输出", cache = "缓存输入", reasoning = "推理", name = "模型名称"
        func value(_ m: ModelUsage) -> Int64 {
            switch self {
            case .total: return m.usage.total
            case .input: return m.usage.input
            case .output: return m.usage.output
            case .cache: return m.usage.cachedInput
            case .reasoning: return m.usage.reasoning
            case .name: return 0
            }
        }
    }
    private var models: [ModelUsage] {
        store.report.models(in: period)
            .filter { search.isEmpty || $0.model.localizedCaseInsensitiveContains(search) }
            .sorted { sort.value($0) == sort.value($1) ? $0.model < $1.model : sort.value($0) > sort.value($1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .bottom) {
                SectionHeader(title: "模型消耗明细", subtitle: "按模型拆分输入、缓存、输出和推理 Token")
                Spacer()
                TextField("搜索模型", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
            }
            Picker("排序", selection: $sort) {
                ForEach(ModelSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.frame(width: 200)
            if models.isEmpty {
                EmptyViewCard(title: "没有匹配的模型", subtitle: "请切换时间范围或查看设置中的日志路径。")
            } else {
                // Native Table owns horizontal scrolling and keeps the first column visible.
                Table(models) {
                    TableColumn("模型") { model in
                        Text(model.model).fontWeight(.semibold)
                            .lineLimit(1).help(model.model)
                    }.width(150)
                    TableColumn("输入") { column($0.usage.input) }.width(76)
                    TableColumn("缓存输入") { column($0.usage.cachedInput, known: $0.usage.cachedInputKnown) }.width(76)
                    TableColumn("非缓存输入") { column($0.usage.uncachedInput, known: $0.usage.cachedInputKnown) }.width(76)
                    TableColumn("输出") { column($0.usage.output) }.width(76)
                    TableColumn("推理") { column($0.usage.reasoning, known: $0.usage.reasoningKnown) }.width(76)
                    TableColumn("总计") { column($0.usage.total, emphasized: true) }.width(76)
                    TableColumn("会话") { model in
                        Text("\(model.sessionCount)").monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }.width(44)
                }
                .accessibilityIdentifier("model-table")
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("Input 包含 Cached，Output 包含 Reasoning。统计为本地日志还原值，不等同于订阅消耗百分比。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(30)
    }

    private func column(_ count: Int64, emphasized: Bool = false, known: Bool = true) -> some View {
        Text(abbreviated(count, known: known))
            .font(.system(size: 12, weight: emphasized ? .semibold : .regular, design: .rounded))
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .help(detailedNumber(count, known: known))
    }
}
