#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import SwiftUI
import AppKit

struct MenuPanelView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.openWindow) private var openWindow
    @StateObject private var menuWindow = MenuWindowOwner()

    var body: some View {
        let usage = store.report.totals(in: store.period)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                CPLogo(size: 27)
                Text("Codex Stats").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { store.refresh() } label: {
                    if store.loading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(store.loading)
                .help("重新扫描本地日志")
            }

            PeriodPicker(selection: $store.period, width: 260)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if store.hasReport {
                        Text(abbreviated(usage.total))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .help(detailedNumber(usage.total) + " tokens")
                        Text("tokens").font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        Text(store.loading ? "正在读取本地日志…" : "尚未取得用量")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                if store.hasReport {
                    HStack(spacing: 14) {
                        metric("输入", usage.input, tint: CPTheme.cyan)
                        metric("输出", usage.output, tint: CPTheme.purple)
                    }
                    HStack(spacing: 14) {
                        metric("缓存", usage.cachedInput, tint: CPTheme.accent, known: usage.cachedInputKnown)
                        metric("推理", usage.reasoning, tint: CPTheme.orange, known: usage.reasoningKnown)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CPTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .help("总计 = 输入 + 输出。缓存包含在输入中，推理包含在输出中。")

            VStack(alignment: .leading, spacing: 8) {
                Text("主要模型").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                let models = store.report.models(in: store.period)
                if models.isEmpty {
                    Text(!store.hasReport ? "等待扫描结果" : "该时间范围没有使用记录")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(models.prefix(2))) { model in
                        VStack(spacing: 4) {
                            HStack {
                                Text(model.model).lineLimit(1).help(model.model)
                                Spacer(minLength: 8)
                                Text(abbreviated(model.usage.total)).monospacedDigit()
                                    .help(detailedNumber(model.usage.total) + " tokens")
                            }.font(.system(size: 11, weight: .medium))
                            GeometryReader { geometry in
                                Capsule().fill(CPTheme.accent.opacity(0.09))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(CPTheme.accent)
                                            .frame(width: geometry.size.width * CGFloat(Double(model.usage.total) / Double(max(models.first?.usage.total ?? 1, 1))))
                                    }
                            }.frame(height: 3)
                        }
                    }
                }
            }

            if let error = store.errorMessage {
                Text(error).font(.system(size: 10)).foregroundStyle(CPTheme.orange)
                    .lineLimit(2).help(error)
            }
            if !store.report.diagnostics.isEmpty {
                let warnings = store.report.diagnostics.filter { $0.severity != .information }.count
                Button(action: showAnalysis) {
                    HStack(spacing: 5) {
                        Image(systemName: warnings > 0 ? "exclamationmark.triangle" : "info.circle")
                        Text("统计状态 · \(warnings) 条警告 / 错误 · \(store.report.diagnostics.count - warnings) 条信息")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 9))
                    }.font(.system(size: 10)).foregroundStyle(warnings > 0 ? CPTheme.orange : CPTheme.cyan)
                }
                .buttonStyle(.plain)
                .help("在完整分析中查看统计提示详情")
            }

            Button(action: showAnalysis) {
                HStack {
                    Image(systemName: "chart.bar.xaxis")
                    Text("打开完整分析")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 10))
                }
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 9)
                .background(CPTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.lastSuccessfulRefresh.map { "刷新于 \($0.formatted(date: .omitted, time: .standard))" } ?? "尚未成功刷新")
                    Text(store.autoRefresh ? "每 \(store.refreshInterval.label)刷新 · 本地只读" : "手动刷新 · 本地只读")
                }.font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Label("退出", systemImage: "power").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("退出 Codex Stats（⌘Q）")
                .accessibilityIdentifier("quit-app")
            }
        }
        .padding(14)
        .frame(width: 288)
        .background(CPTheme.viewBackground)
        .background(MenuWindowProbe(owner: menuWindow).frame(width: 0, height: 0))
    }

    private func showAnalysis() {
        menuWindow.openAnalysis {
            openWindow(id: "dashboard")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func metric(_ title: String, _ number: Int64, tint: Color, known: Bool = true) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text(abbreviated(number, known: known)).fontWeight(.medium).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.85)
        }
        .font(.system(size: 10))
        .frame(maxWidth: .infinity)
        .help(title + " " + detailedNumber(number, known: known) + " tokens")
    }
}
