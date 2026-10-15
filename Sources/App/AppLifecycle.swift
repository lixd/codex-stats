import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = true
        ProcessInfo.processInfo.disableAutomaticTermination("Codex Stats menu bar resident")
        // Copies installed under either product name share the same bundle identity.
        guard let identifier = Bundle.main.bundleIdentifier else { return }
        let instances = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { !$0.isTerminated }
            .sorted {
                let lhs = $0.launchDate ?? .distantPast
                let rhs = $1.launchDate ?? .distantPast
                return lhs == rhs ? $0.processIdentifier < $1.processIdentifier : lhs < rhs
            }
        if let existing = instances.first,
           existing.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            existing.activate(options: [])
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

// Capture the menu's own hosting window rather than whichever window has focus.
final class MenuWindowOwner: ObservableObject {
    weak var window: NSWindow?

    func openAnalysis(_ open: () -> Void) {
        window?.close()
        open()
    }
}

struct MenuWindowProbe: NSViewRepresentable {
    let owner: MenuWindowOwner

    func makeNSView(context: Context) -> ProbeView { ProbeView(owner: owner) }
    func updateNSView(_ view: ProbeView, context: Context) {}

    final class ProbeView: NSView {
        private let owner: MenuWindowOwner
        private weak var attachedWindow: NSWindow?
        init(owner: MenuWindowOwner) {
            self.owner = owner
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window {
                attachedWindow = window
                owner.window = window
            } else {
                if owner.window === attachedWindow { owner.window = nil }
                attachedWindow = nil
            }
        }
    }
}
