import AppKit
import SwiftUI

// Throwaway design comparison. All amounts are synthetic, never loaded from local logs.
private struct MenuProposal: View {
    let dashboard: Bool
    private let metrics: [(String, Int64, Color)] = [
        ("输入", 304_810_000, CPTheme.cyan), ("输出", 1_270_000, CPTheme.purple),
        ("缓存输入", 297_240_000, CPTheme.accent), ("推理", 437_800, CPTheme.orange)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CPLogo(size: 24)
                Text("Codex Stats").font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "arrow.clockwise").foregroundStyle(.secondary)
            }
            Picker("时间范围", selection: .constant(0)) {
                Text("今天").tag(0)
                Text("7 天").tag(1)
                Text("30 天").tag(2)
                Text("全部").tag(3)
            }.pickerStyle(.segmented).labelsHidden().controlSize(.small).frame(width: 260)
            if dashboard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("今日用量").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    total
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CPTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(metrics.indices, id: \.self) { index in
                        let metric = metrics[index]
                        VStack(alignment: .leading, spacing: 6) {
                            Label(metric.0, systemImage: "circle.fill")
                                .font(.system(size: 9)).foregroundStyle(metric.2)
                            Text(abbreviated(metric.1)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                            .background(CPTheme.cardBackground, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(CPTheme.stroke))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日用量").font(.system(size: 10)).foregroundStyle(.secondary)
                    total
                }
                VStack(spacing: 0) {
                    ForEach(metrics.indices, id: \.self) { index in
                        HStack {
                            Circle().fill(metrics[index].2).frame(width: 5, height: 5)
                            Text(metrics[index].0).foregroundStyle(.secondary)
                            Spacer()
                            Text(abbreviated(metrics[index].1)).fontWeight(.medium).monospacedDigit()
                        }.font(.system(size: 11)).padding(.vertical, 5)
                        if index < metrics.count - 1 { Divider().opacity(0.5) }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("主要模型").font(.system(size: 10)).foregroundStyle(.secondary)
                model("gpt-6.1-sol", amount: 301_460_000, share: 1)
                model("Unknown model", amount: 4_620_000, share: 0.0153)
            }
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                Text("8 条统计提醒").font(.system(size: 10))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 8))
            }.foregroundStyle(CPTheme.orange)
            HStack {
                Text("打开完整分析")
                Spacer()
                Image(systemName: "arrow.up.right")
            }.font(.system(size: 11, weight: .medium)).padding(.vertical, 9).padding(.horizontal, 10)
                .foregroundStyle(dashboard ? Color.white : Color.primary)
                .background(dashboard ? CPTheme.accent : CPTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(dashboard ? Color.clear : CPTheme.stroke))
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("刷新于 21:57:09")
                    Text("每 30 秒 · 本地只读")
                }.font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Label("退出", systemImage: "power").font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.padding(14).frame(width: 288).background(CPTheme.viewBackground)
    }

    private var total: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("306.08M").font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit()
            Text("tokens").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func model(_ name: String, amount: Int64, share: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name).lineLimit(1)
                Spacer()
                Text(abbreviated(amount)).monospacedDigit()
            }.font(.system(size: 10, weight: .medium))
            if dashboard {
                GeometryReader { geometry in
                    Capsule().fill(CPTheme.accent.opacity(0.1)).overlay(alignment: .leading) {
                        Capsule().fill(CPTheme.accent).frame(width: geometry.size.width * share)
                    }
                }.frame(height: 3)
            }
        }
    }
}

@main
struct MenuDesignPrototype {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do {
                let output = URL(fileURLWithPath: CommandLine.arguments[1])
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                for dashboard in [false, true] {
                    for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                        let view = NSHostingView(rootView: MenuProposal(dashboard: dashboard).environment(\.colorScheme, scheme))
                        let size = view.fittingSize
                        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                        window.isReleasedWhenClosed = false
                        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                        window.contentView = view
                        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
                        window.orderBack(nil)
                        try await Task.sleep(nanoseconds: 500_000_000)
                        view.layoutSubtreeIfNeeded()
                        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds), bitmap.pixelsWide == 576 else {
                            throw NSError(domain: "MenuDesignPrototype", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected 288 point native @2x rendering"])
                        }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "MenuDesignPrototype", code: 2) }
                        let variant = dashboard ? "b-dashboard" : "a-native"
                        try data.write(to: output.appendingPathComponent("\(variant)-\(name).png"))
                        print("\(variant)-\(name): \(Int(size.width)) × \(Int(size.height)) points, synthetic data")
                        window.close()
                    }
                }
                for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
                    let comparison = HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A · 紧凑原生（示例数据）").font(.system(size: 14, weight: .semibold))
                            MenuProposal(dashboard: false)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text("B · 轻量仪表盘（示例数据）").font(.system(size: 14, weight: .semibold))
                            MenuProposal(dashboard: true)
                        }
                    }.padding(20).background(CPTheme.viewBackground).environment(\.colorScheme, scheme)
                    try await captureComparison(comparison, scheme: scheme, path: output.appendingPathComponent("comparison-\(name).png"))
                }
                print("PASS: four native design previews and two comparisons; synthetic data only, no persisted preferences")
                app.terminate(nil)
            } catch {
                fputs("FAIL: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    @MainActor private static func captureComparison<V: View>(_ root: V, scheme: ColorScheme, path: URL) async throws {
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: view.fittingSize), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = view
        window.setFrameOrigin(NSPoint(x: -3000, y: -3000))
        window.orderBack(nil)
        try await Task.sleep(nanoseconds: 500_000_000)
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw NSError(domain: "MenuDesignPrototype", code: 3) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "MenuDesignPrototype", code: 4) }
        try data.write(to: path)
        window.close()
    }

}
