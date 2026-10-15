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
    private var matching: [SessionUsage] {
        store.report.recentSessions(in: period).filter { session in
            search.isEmpty || session.title.localizedCaseInsensitiveContains(search)
                || session.project.localizedCaseInsensitiveContains(search)
                || session.id.localizedCaseInsensitiveContains(search)
                || session.modelUsage(in: period).contains { $0.model.localizedCaseInsensitiveContains(search) }
        }.sorted {
            switch sort {
            case .recent: return $0.lastActivity > $1.lastActivity
            case .tokens: return $0.usage(in: period).total > $1.usage(in: period).total
            case .project: return $0.project == $1.project ? $0.id < $1.id : $0.project < $1.project
            }
        }
    }

    private var selectedSession: SessionUsage? {
        matching.first(where: { $0.id == selectedID }) ?? matching.first
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                SectionHeader(title: "历史会话", subtitle: "\(matching.count) 个本地会话")
                TextField("搜索项目、模型或 Session ID", text: $search)
                    .textFieldStyle(.roundedBorder)
                Picker("排序", selection: $sort) {
                    ForEach(SessionSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Divider()
                if matching.isEmpty {
                    EmptyViewCard(title: "暂无会话", subtitle: "换个时间范围，或检查 Codex 的日志路径。")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 7) {
                            ForEach(matching) { session in
                                Button { selectedID = session.id } label: {
                                    SessionListRow(session: session,
                                        period: period, selected: selectedSession?.id == session.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.trailing, 5)
                    }
                }
            }
            .padding(24)
            .frame(width: 360)
            Divider()
            if let selection = selectedSession {
                SessionDetailView(session: selection, period: period)
                    .id(selection.id)
            } else {
                EmptyViewCard(title: "选择一个会话", subtitle: "右侧将展示会话中的模型和用量明细。")
            }
        }
    }
}

private struct SessionListRow: View {
    let session: SessionUsage
    let period: UsagePeriod
    let selected: Bool
    private var usage: TokenUsage { session.usage(in: period) }

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
            Text(session.id).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
            HStack {
                Text(abbreviated(usage.total) + " tokens")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer()
                Text(session.modelUsage(in: period).map(\.model).joined(separator: ", "))
                    .lineLimit(1)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(selected ? CPTheme.accent.opacity(0.105) : CPTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(selected ? CPTheme.accent.opacity(0.36) : CPTheme.stroke))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SessionDetailView: View {
    let session: SessionUsage
    let period: UsagePeriod
    private var usage: TokenUsage { session.usage(in: period) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .textSelection(.enabled)
                        Label(session.project, systemImage: "folder")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(session.workingDirectory.isEmpty ? session.id : session.workingDirectory)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.id, forType: .string)
                    } label: {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
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
                            .font(.system(size: 37, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(abbreviated(usage.total) + " tokens")
                            .help(detailedNumber(usage.total) + " tokens")
                            .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                        Divider()
                        TokenDetails(usage: usage)
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
                    ForEach(session.modelUsage(in: period)) { model in
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
                Text("Session ID: \(session.id)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(26)
        }
        .background(CPTheme.viewBackground)
    }
}

struct SettingsContent: View {
    @EnvironmentObject private var store: UsageStore
    @ViewState(initialValue: "") private var editingPath: String

    var body: some View {
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
                                .tint(CPTheme.accent)
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
                        DiagnosticSummary(diagnostics: store.report.diagnostics)
                        if let error = store.errorMessage { StatusBanner(message: error) }
                    }
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(30)
        }
        .onAppear { editingPath = store.rootPath }
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
