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

enum CPTheme {
    static let accent = Color(red: 0.14, green: 0.60, blue: 0.53)
    static let cyan = Color(red: 0.19, green: 0.61, blue: 0.80)
    static let purple = Color(red: 0.55, green: 0.47, blue: 0.82)
    static let orange = Color(red: 0.85, green: 0.53, blue: 0.29)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let viewBackground = Color(nsColor: .windowBackgroundColor)
    static let stroke = Color.primary.opacity(0.065)
}

struct CPLogo: View {
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.12, green: 0.27, blue: 0.29),
                                              Color(red: 0.08, green: 0.13, blue: 0.17)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: size * 0.48, weight: .medium))
                .foregroundStyle(Color(red: 0.56, green: 0.92, blue: 0.77))
        }
        .frame(width: size, height: size)
    }
}

struct Surface<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .background(CPTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(CPTheme.stroke))
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

extension Date {
    var cpDateTime: String { formatted(date: .abbreviated, time: .shortened) }
}

struct MetricTile: View {
    let label: String
    let number: Int64
    let tint: Color
    let systemImage: String
    var known = true
    let caption: String

    var body: some View {
        Surface(padding: 16) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: systemImage).foregroundStyle(tint)
                    Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                }
                Text(abbreviated(number, known: known))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.65)
                    .contentTransition(.numericText())
                    .help(detailedNumber(number, known: known) + " tokens")
                Text(known ? caption : "日志未完整记录\(label)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    Capsule().fill(CPTheme.accent.opacity(0.10))
                    Capsule().fill(CPTheme.accent)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 27, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

struct TokenDetails: View {
    let usage: TokenUsage
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 9) {
            row("输入 Token", usage.input)
            row("缓存输入", usage.cachedInput, known: usage.cachedInputKnown)
            row("非缓存输入", usage.uncachedInput, known: usage.cachedInputKnown)
            row("输出 Token", usage.output)
            row("推理 Token", usage.reasoning, known: usage.reasoningKnown)
            row("总 Token", usage.total)
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
    var compact = false
    @ViewState(initialValue: false) private var expanded: Bool
    init(diagnostics: [ScanDiagnostic], compact: Bool = false, initiallyExpanded: Bool = false) {
        self.diagnostics = diagnostics; self.compact = compact
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
                if compact {
                    ScrollView { detailGroups }.frame(height: 120)
                } else {
                    detailGroups
                }
            } label: {
                Label(warningCount > 0 ? "统计状态 · \(warningCount) 条警告 / 错误 · \(diagnostics.count - warningCount) 条信息" : "统计状态 · \(diagnostics.count) 条信息",
                      systemImage: warningCount > 0 ? "exclamationmark.triangle" : "info.circle")
                    .font(.system(size: compact ? 10 : 12, weight: .medium))
                    .foregroundStyle(warningCount > 0 ? CPTheme.orange : CPTheme.cyan)
            }
            .padding(compact ? 10 : 14)
            .background((warningCount > 0 ? CPTheme.orange : CPTheme.cyan).opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
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
    private func color(_ severity: DiagnosticSeverity) -> Color { severity == .information ? CPTheme.cyan : CPTheme.orange }
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
