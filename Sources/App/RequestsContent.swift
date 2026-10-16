#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import AppKit

struct RequestsContent: View {
    @EnvironmentObject private var store: UsageStore
    let period: UsagePeriod
    @ViewState(initialValue: "") private var search: String
    @ViewState(initialValue: "") private var modelFilter: String
    @ViewState(initialValue: Sort.newest) private var sort: Sort
    @ViewState(initialValue: Optional<String>.none) private var selection: String?
    init(period: UsagePeriod, selectedRecordID: String? = nil, initialModel: String = "") {
        self.period = period
        self._modelFilter = ViewState(initialValue: initialModel)
        self._selection = ViewState(initialValue: selectedRecordID)
    }

    private enum Sort: String, CaseIterable {
        case newest = "最近记录", tokens = "总 Token", model = "模型名称"
    }

    private var records: [UsageRecord] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = store.report.records(in: period, sortedByTime: sort == .newest).filter { record in
            (modelFilter.isEmpty || record.model == modelFilter) &&
            (query.isEmpty || [record.project, record.sessionID, record.model, record.requestID ?? "", record.turnID ?? ""]
                .contains { $0.localizedCaseInsensitiveContains(query) })
        }
        guard sort != .newest else { return filtered }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .newest: return lhs.timestamp == rhs.timestamp ? lhs.id < rhs.id : lhs.timestamp > rhs.timestamp
            case .tokens: return lhs.usage.total == rhs.usage.total ? lhs.id < rhs.id : lhs.usage.total > rhs.usage.total
            case .model: return lhs.model == rhs.model ? lhs.timestamp > rhs.timestamp : lhs.model < rhs.model
            }
        }
    }

    var body: some View {
        let rows = records
        let total = rows.reduce(Int64(0)) { $0 + $1.usage.total }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(rows.count) 条用量记录").font(.system(size: 16, weight: .semibold))
                Spacer()
                PeriodPicker(selection: $store.period)
            }
            HStack(spacing: 8) {
                TextField("搜索项目、模型、会话或请求 ID", text: $search)
                    .textFieldStyle(.roundedBorder)
                Picker("模型", selection: $modelFilter) {
                    Text("全部模型").tag("")
                    ForEach(Set(store.snapshot.overview.observedModels + (modelFilter.isEmpty ? [] : [modelFilter])).sorted(), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
                Picker("排序", selection: $sort) {
                    ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }
            Text("点击记录查看详情。累计增量与初始快照可能包含多次请求，不等同于已确认的请求数量。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if rows.isEmpty {
                EmptyViewCard(title: "没有匹配的用量记录", subtitle: "尝试其他时间范围、模型或搜索条件。")
                    .frame(maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    requestTable(rows, compact: geometry.size.width < 900)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .background(CPTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CPTheme.stroke))
                }
            }
            HStack {
                Text("当前列表合计 \(abbreviated(total)) tokens")
                    .help(detailedNumber(total) + " tokens")
                Spacer()
                Text("新增输入 = 输入 − 缓存输入")
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CPTheme.viewBackground)
        .sheet(item: Binding(get: { rows.first { $0.id == selection } }, set: { selection = $0?.id })) { record in
            RequestDetailView(record: record, onClose: { selection = nil })
                .frame(width: 420, height: 600)
                .environment(\.appPalette, store.palette)
        }
        .onChange(of: period) { _, _ in modelFilter = "" }
        .onExitCommand { selection = nil }

    }

    @ViewBuilder private func requestTable(_ rows: [UsageRecord], compact: Bool) -> some View {
        // Pair related fields at narrow widths; every value remains visible and
        // the native Table remains the only scrolling container.
        if compact {
            Table(rows, selection: $selection) {
                TableColumn("时间") { time($0) }.width(60)
                TableColumn("项目 / 会话") { project($0) }.width(min: 70, ideal: 70, max: 100)
                TableColumn("模型 / 类型") { record in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.model).lineLimit(1).help(record.model)
                        evidence(record)
                    }
                }.width(min: 88, ideal: 88, max: 150)
                TableColumn("新增 / 缓存") { record in
                    VStack(alignment: .trailing, spacing: 3) {
                        number(record.usage.uncachedInput, known: record.usage.cachedInputKnown).accessibilityLabel("新增输入").accessibilityValue(detailedNumber(record.usage.uncachedInput, known: record.usage.cachedInputKnown))
                        number(record.usage.cachedInput, known: record.usage.cachedInputKnown).accessibilityLabel("缓存输入").accessibilityValue(detailedNumber(record.usage.cachedInput, known: record.usage.cachedInputKnown))
                    }
                }.width(72)
                TableColumn("输出") { number($0.usage.output) }.width(48)
                TableColumn("总 Token") { number($0.usage.total) }.width(58)
                TableColumn("耗时 / 速度 ≈") { record in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(requestDuration(record)).accessibilityLabel("耗时估算 " + requestDuration(record))
                        Text(requestSpeed(record)).accessibilityLabel("速度估算 " + requestSpeed(record))
                    }.monospacedDigit().help(requestTimingHelp(record))
                }.width(78)
            }
            .accessibilityIdentifier("request-table")
        } else {
            Table(rows, selection: $selection) {
                TableColumn("时间") { time($0) }.width(60)
                TableColumn("项目 / 会话") { project($0) }.width(min: 80, ideal: 80, max: 100)
                TableColumn("模型") { Text($0.model).lineLimit(1).help($0.model) }.width(min: 100, ideal: 100, max: 130)
                TableColumn("新增输入") { number($0.usage.uncachedInput, known: $0.usage.cachedInputKnown) }.width(72)
                TableColumn("输出") { number($0.usage.output) }.width(48)
                TableColumn("缓存输入") { number($0.usage.cachedInput, known: $0.usage.cachedInputKnown) }.width(72)
                TableColumn("总 Token") { number($0.usage.total) }.width(58)
                TableColumn("耗时 ≈") { Text(requestDuration($0)).monospacedDigit().help(requestTimingHelp($0)) }.width(58)
                TableColumn("速度 ≈") { Text(requestSpeed($0)).monospacedDigit().help(requestTimingHelp($0)) }.width(80)
                TableColumn("类型") { evidence($0) }.width(66)
            }
            .accessibilityIdentifier("request-table")
        }
    }

    private func time(_ record: UsageRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(record.timestamp.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)))
            Text(record.timestamp.formatted(.dateTime.month(.twoDigits).day(.twoDigits)))
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }.monospacedDigit().help(record.timestamp.formatted(date: .complete, time: .standard))
    }

    private func project(_ record: UsageRecord) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(record.project).lineLimit(1)
            Text(record.recordedSessionID.map { String($0.prefix(8)) } ?? "未记录")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }.help(record.project + " · " + (record.recordedSessionID ?? "Session ID 未记录"))
    }

    private func evidence(_ record: UsageRecord) -> some View {
        Button(record.isCompaction ? "压缩" : record.evidence.label) { selection = record.id }
            .buttonStyle(.borderless).foregroundStyle(CPTheme.accent)
            .font(.system(size: 10)).help(record.evidence.explanation + " 点击查看详情。")
            .accessibilityIdentifier("open-request-" + (record.requestID ?? record.id))
    }

    private func number(_ value: Int64, known: Bool = true) -> some View {
        Text(abbreviated(value, known: known)).monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
            .help(detailedNumber(value, known: known))
    }
}

struct RequestDetailView: View {
    @EnvironmentObject private var store: UsageStore
    let record: UsageRecord
    var onClose: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("请求 / 用量详情").font(.system(size: 18, weight: .semibold))
                    Text(record.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { onClose() } label: { Image(systemName: "xmark") }
                    .help("关闭详情（Esc）")
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("close-request-detail")
            }
            .padding(20)
            .background(CPTheme.cardBackground)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    performance
                    Surface(padding: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("基本信息").font(.system(size: 13, weight: .semibold))
                            row("项目", record.project)
                            row("模型", record.model)
                            row("来源", record.source)
                            row("Session ID", record.recordedSessionID ?? "未记录")
                            if record.recordedSessionID == nil { row("本地会话归组", record.sessionID) }
                            row("Turn ID", record.turnID ?? "未记录")
                            row("请求 ID（response_id）", record.requestID ?? "未记录")
                            row("日志文件", record.fileName)
                            VStack(alignment: .leading, spacing: 6) {
                                if let session = record.recordedSessionID { copyButton("复制 Session ID", session) }
                                if let request = record.requestID { copyButton("复制请求 ID", request) }
                            }
                        }
                    }
                    Surface(padding: 14) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("已计入的 Token 用量").font(.system(size: 13, weight: .semibold))
                            TokenDetails(usage: record.usage)
                            CacheRateText(usage: record.usage).font(.system(size: 12))
                            CostEstimateText(estimate: store.estimate(record)).font(.system(size: 12))
                            Text("按已计入用量折算；累计记录可能覆盖多次请求，不代表单次请求账单。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Text("新增输入为非缓存输入；缓存包含在输入中，推理包含在输出中。总量 = 输入 + 输出。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Surface(padding: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("统计依据 · \(record.evidence.label)").font(.system(size: 13, weight: .semibold))
                            Text(record.evidence.explanation).font(.system(size: 12)).foregroundStyle(.secondary)
                            if record.isCompaction {
                                Label("上下文压缩用量", systemImage: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11))
                            }
                            if let last = record.lastReportedUsage {
                                DisclosureGroup("日志原始 last_token_usage / usage") { TokenDetails(usage: last).padding(.top, 8) }
                            }
                            if let total = record.cumulativeSnapshot {
                                DisclosureGroup(record.evidence == .responseRecord ? "原始 thread_token_usage（独立累计口径）" : "原始 total_token_usage（不能直接累加）") {
                                    TokenDetails(usage: total).padding(.top, 8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CPTheme.viewBackground)
    }

    private var performance: some View {
        Surface(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("性能").font(.system(size: 13, weight: .semibold))
                Text("请求估算").font(.system(size: 12, weight: .medium))
                row("耗时（估算）", requestDuration(record))
                row("输出速度 ≈", requestSpeed(record))
                Text(requestTimingHelp(record))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Divider()
                Text("完整 Turn · 含工具与等待").font(.system(size: 12, weight: .medium))
                if let timing = record.turnPerformance {
                    row("Turn 耗时", elapsedSeconds(timing.durationMilliseconds))
                    row("首次 Token", timing.firstTokenMilliseconds.map(elapsedSeconds) ?? "—")
                    row("平均输出", timing.averageOutputTokensPerSecond.map {
                        $0.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...2))) + " tok/s"
                    } ?? "—")
                    if let count = timing.responseCount, let output = timing.outputTokens {
                        Text("整段 Turn 的 \(count) 个去重响应，共输出 \(abbreviated(output)) tokens；不受当前日期或列表筛选影响。")
                            .help(detailedNumber(output) + " output tokens")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    } else {
                        Text("Turn 输出覆盖未确认，不计算均速。")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                } else {
                    row("Turn 耗时", "—")
                    row("首次 Token", "—")
                    row("平均输出", "—")
                    Text("未找到可核验的完整 Turn 计时；缺失、中止或冲突的计时不估算。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Text("Turn 平均输出包含工具、推理与等待，不代表纯文本生成速度，也不是这条请求的速度。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).foregroundStyle(.secondary).frame(width: 92, alignment: .leading)
            Text(value).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }

    private func copyButton(_ title: String, _ value: String) -> some View {
        Button(title, systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
        .buttonStyle(.bordered)
    }
}

// Presentation only: Core owns association and eligibility of request estimates.
private func requestDuration(_ record: UsageRecord) -> String {
    record.requestEstimate.map {
        "≈" + (Double($0.durationMilliseconds) / 1000).formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...1))) + " s"
    } ?? "—"
}

private func requestSpeed(_ record: UsageRecord) -> String {
    guard let speed = record.requestEstimate?.outputTokensPerSecond else { return "—" }
    return "≈" + speed.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...1))) + " tok/s"
}

private func requestTimingHelp(_ record: UsageRecord) -> String {
    guard record.requestEstimate != nil else {
        return "缺少可对应到这条请求的日志起止边界，无法估算；压缩及累计快照不填充性能。"
    }
    return "按日志事件起止时间估算，包含首次 Token 等待及可能的重试；不是实测生成速度。输出至少 200 tokens 且耗时至少 1 秒时显示估算速度。"
}
