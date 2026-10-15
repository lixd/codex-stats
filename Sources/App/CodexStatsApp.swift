import SwiftUI
import AppKit


@main
struct CodexStatsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView()
                .environmentObject(store)
        } label: {
            Image(systemName: "waveform.path.ecg.rectangle")
                .accessibilityLabel("Codex Stats")
        }
        .menuBarExtraStyle(.window)

        Window("Codex Stats", id: "dashboard") {
            DashboardView()
                .environmentObject(store)
        }
        .defaultSize(width: 1120, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("退出 Codex Stats") { NSApp.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}
