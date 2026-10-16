#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import AppKit

// Keep the property wrapper unambiguous on SDKs that also export a State macro.
typealias ViewState<Value> = SwiftUI.State<Value>
import Charts

struct QuitAppButton: View {
    var body: some View {
        Button { NSApp.terminate(nil) } label: {
            Label("退出应用", systemImage: "power")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .help("退出 Codex Stats（⌘Q），包括菜单栏图标和分析窗口")
        .accessibilityIdentifier("quit-app")
    }
}

// MARK: - Visual system

struct CPLogo: View {
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(CPTheme.selection)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.48, weight: .medium))
                .foregroundStyle(CPTheme.accent)
        }
        .frame(width: size, height: size)
    }
}

struct Surface<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(CPTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(CPTheme.stroke))
    }
}

func abbreviated(_ value: Int64, known: Bool = true) -> String {
    guard known else { return "未完整记录" }
    return abbreviated(Double(value))
}

func abbreviated(_ value: Double) -> String {
    let format = FloatingPointFormatStyle<Double>.number.locale(Locale(identifier: "en_US_POSIX"))
        .rounded(rule: .toNearestOrAwayFromZero)
    // Promote the rounded 1000K boundary to M instead of displaying 1000K.
    if value >= 999_950 {
        return (value / 1_000_000).formatted(format.grouping(.never).precision(.fractionLength(0...2))) + "M"
    }
    if value >= 10_000 {
        return (value / 1_000).formatted(format.grouping(.never).precision(.fractionLength(0...1))) + "K"
    }
    return value.formatted(format.precision(.fractionLength(0...2)))
}

func detailedNumber(_ value: Int64, known: Bool = true) -> String { known ? value.formatted() : "未完整记录" }

func cacheRateLabel(_ usage: TokenUsage) -> String {
    let rate = CacheRate(usage: usage)
    switch rate.state {
    case .noInput: return "—"
    case .incomplete: return "未完整记录"
    case .known:
        return (rate.fraction! * 100).formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(1))) + "%"
    }
}

func cacheRateHelp(_ usage: TokenUsage) -> String {
    switch CacheRate(usage: usage).state {
    case .noInput: return "缓存率：无输入 Token"
    case .incomplete: return "缓存率：缓存输入未完整记录"
    case .known: return "缓存率：缓存输入 " + detailedNumber(usage.cachedInput) + " ÷ 输入 " + detailedNumber(usage.input) + "；缓存是输入的子集"
    }
}

struct CacheRateText: View {
    let usage: TokenUsage
    var body: some View {
        Text("缓存率 " + cacheRateLabel(usage)).monospacedDigit()
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .help(cacheRateHelp(usage))
            .accessibilityLabel("缓存率")
            .accessibilityValue(cacheRateLabel(usage) + "；" + cacheRateHelp(usage))
    }
}

func dollars(_ amount: Decimal) -> String {
    if amount > 0 && amount < Decimal(string: "0.01")! { return "< $0.01" }
    var value = amount, rounded = Decimal()
    NSDecimalRound(&rounded, &value, 2, .plain)
    let parts = NSDecimalNumber(decimal: rounded).stringValue.split(separator: ".")
    let integer = String(parts[0])
    let grouped = integer.reversed().enumerated().map { index, digit in
        (index > 0 && index % 3 == 0 ? "," : "") + String(digit)
    }.joined().reversed()
    let fraction = parts.count > 1 ? String(parts[1]) : ""
    return "$" + String(grouped) + "." + fraction + String(repeating: "0", count: max(0, 2 - fraction.count))
}

func costHelp(_ estimate: CostEstimate) -> String {
    let exact = estimate.exactUSD
    let fractional = exact.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0
    let padded = exact + (fractional == 0 ? "." : "") + String(repeating: "0", count: max(0, 8 - fractional))
    let amount = estimate.state == .unavailable ? "无法估算金额" : "API 等值估算 " + padded + " USD"
    return amount + "；已估算 " + detailedNumber(estimate.estimatedTokens)
        + " Token；未估算 " + detailedNumber(estimate.unestimatedTokens) + " Token；"
        + costReasons(estimate) + "；USD 参考价；所有历史统一按当前价表折算，非实际扣费；" + ReferencePricing.exclusions
        + "；价表 " + estimate.priceVersion
        + (estimate.priceVersion == "unavailable" ? "；价格配置不可用，未回退默认价" : estimate.priceSources.contains(.custom) ? "；含用户自定义价格，未经官方核验" : estimate.priceSources.isEmpty ? "；没有采用价格的已计价用量；各行来源见模型价格" : "；采用已保存快照的内置参考价；来源和核验日期见设置中的模型价格")
}

func costReasons(_ estimate: CostEstimate) -> String {
    estimate.reasons.keys.sorted { $0.rawValue < $1.rawValue }
        .map { $0.label }.joined(separator: "、")
}

struct CostEstimateText: View {
    let estimate: CostEstimate
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            switch estimate.state {
            case .complete: Text("API 等值估算 ≈ " + dollars(estimate.amountUSD))
            case .partial:
                Text("已估算小计 ≈ " + dollars(estimate.amountUSD))
                Text("另有 " + abbreviated(estimate.unestimatedTokens) + " Token 未估算 · " + costReasons(estimate))
            case .unavailable:
                Text("API 等值估算：无法估算")
                Text(abbreviated(estimate.unestimatedTokens) + " Token 未估算 · " + costReasons(estimate))
            }
        }
        .monospacedDigit().foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .help(costHelp(estimate))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(estimate.state == .partial ? "API 等值估算，已估算小计" : "API 等值估算")
        .accessibilityValue((estimate.state == .unavailable ? "无法估算；" : dollars(estimate.amountUSD) + "；") + costHelp(estimate))
    }
}

extension Date {
    var cpDateTime: String { formatted(date: .abbreviated, time: .shortened) }
}

struct MetricTile: View {
    let label: String
    let number: Int64
    let systemImage: String
    var known = true
    let caption: String
    var emphasized = false
    var cacheUsage: TokenUsage? = nil
    var cost: CostEstimate? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: systemImage).foregroundStyle(CPTheme.accent)
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
            }
            Text(abbreviated(number, known: known))
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(emphasized ? AnyShapeStyle(CPTheme.accent) : AnyShapeStyle(Color.primary))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.65)
                .contentTransition(.numericText())
                .help(detailedNumber(number, known: known) + " tokens")
            if let cost { CostEstimateText(estimate: cost).font(.system(size: 10)) }
            if let cacheUsage { CacheRateText(usage: cacheUsage).font(.system(size: 10)) }
            Text(known ? caption : "日志未完整记录\(label)")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

struct TokenStrip: View {
    let usage: TokenUsage
    var body: some View {
        HStack(spacing: 14) {
            strip("输入", usage.input)
            strip("缓存", usage.cachedInput, known: usage.cachedInputKnown)
            strip("输出", usage.output)
            strip("推理", usage.reasoning, known: usage.reasoningKnown)
        }
    }
    private func strip(_ label: String, _ tokens: Int64, known: Bool = true) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(abbreviated(tokens, known: known)).monospacedDigit().foregroundStyle(.primary)
        }
        .font(.system(size: 11))
    }
}

struct ModelBar: View {
    let model: ModelUsage
    let maxTokens: Int64
    var showSessionCount = true
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text(model.model)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 5)
                Text(abbreviated(model.usage.total))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(CPTheme.selection)
                    Capsule().fill(CPTheme.chart)
                        .frame(width: max(3, geometry.size.width * CGFloat(model.usage.total) / CGFloat(max(1, maxTokens))))
                }
            }
            .frame(height: 6)
            if showSessionCount {
                HStack {
                    Text("输入 \(abbreviated(model.usage.input)) · 输出 \(abbreviated(model.usage.output))")
                    Spacer()
                    Text("\(model.sessionCount) 会话")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatusBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(CPTheme.orange)
            Text(message).textSelection(.enabled).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CPTheme.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyViewCard: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(CPTheme.accent)
            Text(title).font(.headline)
            Text(subtitle)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 390)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
    }
}

struct PeriodPicker: View {
    @Binding var selection: UsagePeriod
    var width: CGFloat = 292
    var body: some View {
        Picker("时间", selection: $selection) {
            ForEach(UsagePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: width)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String
    var titleSize: CGFloat = 23
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: titleSize, weight: .semibold))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

struct TokenDetails: View {
    let usage: TokenUsage
    var showTotal = true
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 9) {
            row("输入 Token", usage.input)
            row("缓存输入", usage.cachedInput, known: usage.cachedInputKnown)
            row("非缓存输入", usage.uncachedInput, known: usage.cachedInputKnown)
            row("输出 Token", usage.output)
            row("推理 Token", usage.reasoning, known: usage.reasoningKnown)
            if showTotal { row("总 Token", usage.total) }
        }
        .font(.system(size: 12))
        .textSelection(.enabled)
    }
    private func row(_ title: String, _ value: Int64, known: Bool = true) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(abbreviated(value, known: known)).monospacedDigit().gridColumnAlignment(.trailing)
                .help(detailedNumber(value, known: known))
        }
    }
}


/// Group structured diagnostics without turning normal history metadata into warnings.
struct DiagnosticSummary: View {
    let diagnostics: [ScanDiagnostic]
    @ViewState(initialValue: false) private var expanded: Bool
    init(diagnostics: [ScanDiagnostic], initiallyExpanded: Bool = false) {
        self.diagnostics = diagnostics
        self._expanded = ViewState(initialValue: initiallyExpanded)
    }

    private var warningCount: Int { diagnostics.filter { $0.severity != .information }.count }
    private var groups: [(key: String, entries: [ScanDiagnostic])] {
        Dictionary(grouping: diagnostics, by: { $0.severity.rawValue + ":" + $0.kind.rawValue })
            .map { (key: $0.key, entries: $0.value) }
            .sorted { lhs, rhs in
                let a = rank(lhs.entries[0].severity), b = rank(rhs.entries[0].severity)
                return a == b ? lhs.key < rhs.key : a < b
            }
    }
    var body: some View {
        if !diagnostics.isEmpty {
            DisclosureGroup(isExpanded: $expanded) {
                detailGroups
            } label: {
                Label(warningCount > 0 ? "统计状态 · \(warningCount) 条警告 / 错误 · \(diagnostics.count - warningCount) 条信息" : "统计状态 · \(diagnostics.count) 条信息",
                      systemImage: warningCount > 0 ? "exclamationmark.triangle" : "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(warningCount > 0 ? CPTheme.orange : CPTheme.accent)
            }
            .padding(14)
            .background(warningCount > 0 ? AnyShapeStyle(CPTheme.orange.opacity(0.06)) : AnyShapeStyle(CPTheme.selection), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    private var detailGroups: some View {
                VStack(alignment: .leading, spacing: 12) {
                    Text("涉及全部扫描日志，不限于当前筛选。信息表示已核验的处理；警告 / 错误可能影响统计完整性。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    ForEach(groups, id: \.key) { group in
                        let first = group.entries[0]
                        DisclosureGroup {
                            ForEach(Array(group.entries.enumerated()), id: \.offset) { _, diagnostic in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(diagnostic.message).textSelection(.enabled)
                                    if let file = diagnostic.fileName {
                                        Text(file).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }.font(.system(size: 11)).padding(.vertical, 4)
                            }
                        } label: {
                            Label("\(label(first.kind)) · \(group.entries.count)", systemImage: icon(first.severity))
                                .foregroundStyle(color(first.severity)).font(.system(size: 11, weight: .medium))
                        }
                    }
                }.padding(.top, 8)
    }
    private func rank(_ severity: DiagnosticSeverity) -> Int {
        switch severity { case .error: return 0; case .warning: return 1; case .information: return 2 }
    }
    private func color(_ severity: DiagnosticSeverity) -> CPTheme { severity == .information ? CPTheme.cyan : CPTheme.orange }
    private func icon(_ severity: DiagnosticSeverity) -> String { severity == .information ? "info.circle" : "exclamationmark.triangle" }
    private func label(_ kind: DiagnosticKind) -> String {
        switch kind {
        case .unreadableFile: return "读取失败"
        case .invalidJSON: return "损坏日志"
        case .partialWrite: return "等待完整写入"
        case .invalidUsage: return "非法用量"
        case .incompleteFields: return "字段未完整记录"
        case .missingIdentity: return "身份未完整记录"
        case .missingTimestamp: return "时间未记录"
        case .counterAmbiguity: return "累计覆盖不确定"
        case .inheritedHistory: return "继承覆盖不确定"
        case .overflow: return "数值溢出"
        case .invalidTimeBucket: return "小时归属不完整"
        case .historyReference: return "已核验历史引用"
        case .unresolvedHistoryReference: return "历史引用无法核验"
        case .supersededCopy: return "已去重副本"
        case .mergedPhysicalHistory: return "已合并物理历史"
        case .divergentAccountingCopies: return "旧格式副本覆盖不确定"
        case .conflictingResponse: return "响应身份冲突"
        }
    }
}

func elapsedSeconds(_ milliseconds: Int64) -> String {
    (Double(milliseconds) / 1000).formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
        .grouping(.never).precision(.fractionLength(0...3))) + " s"
}


struct PendingUsageView: View {
    let loading: Bool
    let error: String?
    var body: some View {
        VStack(spacing: 16) {
            if loading { ProgressView() }
            EmptyViewCard(title: loading ? "正在读取本地日志…" : "尚未取得用量",
                          subtitle: error ?? "首次扫描完成后显示统计结果。")
        }.padding(24)
    }
}
