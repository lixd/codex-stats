#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import AppKit

struct SessionsContent: View {
    @EnvironmentObject private var store: UsageStore
    let period: UsagePeriod
    @ViewState(initialValue: "") private var search: String
    @ViewState<String?>(initialValue: nil) private var selectedID: String?

    @ViewState(initialValue: SessionSort.recent) private var sort: SessionSort
    private enum SessionSort: String, CaseIterable {
        case recent = "最近活动", tokens = "Token 用量", project = "项目名称"
    }

    private func matching(now: Date) -> [SessionUsageRow] {
        let rows = store.report.sessionRows(in: period, now: now).filter { row in
            search.isEmpty || row.session.title.localizedCaseInsensitiveContains(search)
                || row.session.project.localizedCaseInsensitiveContains(search)
                || (row.session.recordedSessionID?.localizedCaseInsensitiveContains(search) ?? false)
                || row.models.contains(where: { $0.model.localizedCaseInsensitiveContains(search) })
        }
        return rows.sorted {
            switch sort {
            case .recent: return $0.session.lastActivity == $1.session.lastActivity
                ? $0.id < $1.id : $0.session.lastActivity > $1.session.lastActivity
            case .tokens: return $0.usage.total == $1.usage.total ? $0.id < $1.id : $0.usage.total > $1.usage.total
            case .project: return $0.session.project == $1.session.project ? $0.id < $1.id : $0.session.project < $1.session.project
            }
        }
    }

    var body: some View {
        let now = Date()
        let rows = matching(now: now)
        let valuation = store.summary(in: period, now: now).valuation
        let selected = rows.first(where: { $0.id == selectedID }) ?? rows.first
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(title: "历史会话", subtitle: "\(rows.count) 个本地会话", titleSize: 18)
                TextField("搜索项目、模型或 Session ID", text: $search)
                    .textFieldStyle(.roundedBorder)
                Picker("排序", selection: $sort) {
                    ForEach(SessionSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Divider()
                if rows.isEmpty {
                    EmptyViewCard(title: "暂无会话", subtitle: "换个时间范围，或检查 Codex 的日志路径。")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(rows) { row in
                                Button { selectedID = row.id } label: {
                                    SessionListRow(session: row.session, usage: row.usage, models: row.models,
                                        selected: selected?.id == row.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selected?.id == row.id ? .isSelected : [])
                            }
                        }
                        .padding(.trailing, 5)
                    }
                }
            }
            .padding(16)
            .frame(width: 280)
            .background(CPTheme.sectionBackground)
            Divider()
            if let selected {
                SessionDetailView(session: selected.session, period: period, usage: selected.usage, models: selected.models, cost: valuation.sessions[selected.id] ?? CostEstimate(priceVersion: store.snapshot.valuation.catalogRevision), modelCosts: valuation.sessionModels[selected.id] ?? [:])
                    .id(selected.id)
            } else {
                EmptyViewCard(title: "选择一个会话", subtitle: "右侧将展示会话中的模型和用量明细。")
            }
        }
    }
}

private struct SessionListRow: View {
    let session: SessionUsage
    let usage: TokenUsage
    let models: [ModelUsage]
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(session.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if session.replayUnverified {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(CPTheme.orange)
                        .help("子会话的继承历史未能完全去重")
                }
            }
            HStack(spacing: 5) {
                Image(systemName: "folder")
                Text(session.project)
                Text("·")
                Text(session.lastActivity.cpDateTime)
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
            Text(session.recordedSessionID ?? "Session ID 未记录").help(session.recordedSessionID ?? "Session ID 未记录").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
            HStack {
                Text(abbreviated(usage.total) + " tokens")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer()
                Text(models.map(\.model).joined(separator: ", "))
                    .lineLimit(1)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(selected ? CPTheme.selection : CPTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .strokeBorder(selected ? CPTheme.accent : CPTheme.stroke))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SessionDetailView: View {
    let session: SessionUsage
    let period: UsagePeriod
    let usage: TokenUsage
    let models: [ModelUsage]
    let cost: CostEstimate
    let modelCosts: [String: CostEstimate]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title)
                            .font(.system(size: 21, weight: .semibold))
                            .textSelection(.enabled)
                        Label(session.project, systemImage: "folder")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(session.workingDirectory.isEmpty ? "项目路径未记录" : session.workingDirectory)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        guard let id = session.recordedSessionID else { return }
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(id, forType: .string)
                    } label: {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(session.recordedSessionID == nil)
                    .help(session.recordedSessionID == nil ? "Session ID 未记录" : "复制 Session ID")
                }
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("会话 Token · \(period.rawValue)")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(session.source)
                                .font(.system(size: 10)).foregroundStyle(.tertiary)
                        }
                        Text(abbreviated(usage.total))
                            .font(.system(size: 37, weight: .semibold))
                            .foregroundStyle(CPTheme.accent)
                            .monospacedDigit()
                            .help(detailedNumber(usage.total) + " tokens")
                        Divider()
                        TokenDetails(usage: usage, showTotal: false)
                        CacheRateText(usage: usage).font(.system(size: 12))
                        CostEstimateText(estimate: cost).font(.system(size: 12))
                        HStack {
                            Text("开始 \(session.firstActivity.cpDateTime)")
                            Spacer()
                            Text("最后活动 \(session.lastActivity.cpDateTime)")
                        }
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("会话内模型明细")
                        .font(.system(size: 14, weight: .semibold))
                    ForEach(models) { model in
                        Surface(padding: 14) {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text(model.model)
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text(abbreviated(model.usage.total))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                }
                                TokenDetails(usage: model.usage)
                                CacheRateText(usage: model.usage).font(.system(size: 12))
                                CostEstimateText(estimate: modelCosts[model.model] ?? CostEstimate(priceVersion: cost.priceVersion)).font(.system(size: 12))
                            }
                        }
                    }
                }
                if session.replayDeduplicated {
                    Label("已扣除匹配到的父会话继承快照", systemImage: "checkmark.shield")
                        .font(.system(size: 11)).foregroundStyle(CPTheme.accent)
                }
                if session.replayUnverified {
                    StatusBanner(message: "该会话包含分叉/子 Agent 历史，未能核实继承快照。用量可能偏高，请勿用于精确计费。")
                }
                Text("Session ID: \(session.recordedSessionID ?? "未记录")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(CPTheme.viewBackground)
    }
}

struct SettingsContent: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.self) private var environment
    @ViewState(initialValue: "") private var editingPath: String
    @ViewState(initialValue: false) private var showingPrices: Bool

    init(initialShowingPrices: Bool = false) { _showingPrices = ViewState(initialValue: initialShowingPrices) }

    var body: some View {
        Group {
            if showingPrices {
                PriceManagementContent { showingPrices = false }
            } else {
                settings
            }
        }
        .onAppear { editingPath = store.rootPath }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "偏好设置", subtitle: "所有数据处理都在本机完成，不使用 API Key 或网络服务")
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Codex 日志位置", systemImage: "folder.badge.gearshape")
                            .font(.system(size: 14, weight: .semibold))
                        Text("默认读取 ~/.codex 下的 sessions 和 archived_sessions；可以自行指定 CODEX_HOME。")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            TextField("日志目录", text: $editingPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            Button("保存并扫描") { store.updateRoot(editingPath) }
                                .buttonStyle(.borderedProminent)
                                .tint(CPTheme.actionFill.resolve(in: environment))
                        }
                        HStack {
                            Button("在 Finder 中打开") {
                                let first = store.rootPath.split(separator: ",").first.map(String.init) ?? store.rootPath
                                let expanded = NSString(string: first).expandingTildeInPath
                                NSWorkspace.shared.open(URL(fileURLWithPath: expanded))
                            }
                            Spacer()
                            Toggle("自动刷新", isOn: $store.autoRefresh)
                                .toggleStyle(.switch).font(.system(size: 11))
                        }
                        Picker("刷新间隔", selection: $store.refreshInterval) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.label).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!store.autoRefresh)
                        .frame(width: 220, alignment: .leading)
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("配色", selection: $store.palette) {
                            ForEach(AppPalette.allCases) { palette in
                                Text(palette.label).tag(palette)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220, alignment: .leading)
                        .accessibilityIdentifier("color-palette")
                        Text("只改变配色，外观跟随系统")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("API 等值估算参考", systemImage: "dollarsign.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text(store.catalog?.description ?? "价格配置不可用")
                        Text("仅参考非缓存输入、缓存输入和输出；推理已包含在输出中。未知模型或缓存拆分缺失时不猜价。")
                        Text(ReferencePricing.exclusions)
                        Text("价表：" + (store.catalog?.revision ?? "不可用") + "；各模型来源与核验日期见管理页")
                        if let error = store.priceError { StatusBanner(message: error) }
                        Button("管理模型价格") { showingPrices = true }
                            .accessibilityIdentifier("manage-model-prices")
                        Text(ReferencePricing.source).textSelection(.enabled)
                    }
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Surface {
                    VStack(alignment: .leading, spacing: 13) {
                        Label("数据与隐私", systemImage: "lock.shield")
                            .font(.system(size: 14, weight: .semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            line("只读取 .jsonl 会话日志；不会访问 auth.json 或 OpenAI 网络接口。")
                            line("模型消耗按本地累计快照还原，不能换算订阅的 5 小时/每周额度。")
                            line("不上传、不发送、不保存原始会话全文；文件缓存只保存在应用内存。")
                            line("包含子 Agent 继承历史或远程压缩时，部分用量可能无法精确归属。")
                        }
                    }
                }
                Surface {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("扫描状态", systemImage: "checkmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("会话文件：\(store.report.fileCount) · 会话数量：\(store.report.sessions.count)")
                        Text(store.lastSuccessfulRefresh.map { "上次成功扫描：\($0.formatted(date: .abbreviated, time: .standard))" } ?? "尚未成功扫描")
                        Text("无效日志行：\(store.report.invalidLineCount) · 复用缓存：\(store.report.cachedFileCount) 份")
                        if !store.hasReport, let error = store.errorMessage { StatusBanner(message: error) }
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }

    private func line(_ string: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CPTheme.accent)
            Text(string).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }
}
