import AppKit
import SwiftUI

@main
struct MenuLifecycleCheck {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        var launchObserved = false
        let launchObserver = NotificationCenter.default.addObserver(forName: NSApplication.willFinishLaunchingNotification,
                                                                    object: app, queue: nil) { _ in launchObserved = true }
        let menuOwner = MenuWindowOwner()
        let menu = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
                            styleMask: [.borderless], backing: .buffered, defer: false)
        menu.isReleasedWhenClosed = false
        let probe = MenuWindowProbe.ProbeView(owner: menuOwner)
        menu.contentView?.addSubview(probe)
        require(menuOwner.window === menu, "Probe must capture its own hosting window")
        let dashboard = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
        dashboard.isReleasedWhenClosed = false
        menu.orderFront(nil)
        dashboard.makeKeyAndOrderFront(nil)
        var opened = false
        menuOwner.openAnalysis {
            require(!menu.isVisible, "Menu must close before opening analysis")
            require(dashboard.isVisible, "Handoff must not close dashboard")
            opened = true
        }
        require(opened, "Analysis action must run")
        // Reusing the same hosting window must keep working on the next opening.
        menu.orderFront(nil)
        require(menu.isVisible, "Closed menu window must be reusable")
        menuOwner.openAnalysis { require(!menu.isVisible, "Second handoff must dismiss menu") }
        menu.contentView = NSView()
        require(menuOwner.window == nil, "Detached probe must release hosting association")
        // The framework may create a different hosting window on a later opening.
        let replacement = NSWindow(contentRect: menu.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        replacement.isReleasedWhenClosed = false
        replacement.contentView?.addSubview(probe)
        replacement.orderFront(nil)
        require(menuOwner.window === replacement, "Probe must follow replacement hosting window")
        menuOwner.openAnalysis {
            require(!replacement.isVisible, "Replacement menu must dismiss")
            require(dashboard.isVisible, "Unrelated dashboard must remain open")
        }
        dashboard.close()
        require(!delegate.applicationShouldTerminateAfterLastWindowClosed(app), "Last-window policy must preserve resident process")
        var aliveAfterClose = false
        let terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                                                          object: app, queue: nil) { _ in
            require(aliveAfterClose, "App must remain alive before explicit termination")
            print("PASS: exact-window handoff order, dashboard ownership, reused/replaced menu, resident policy, explicit termination")
        }
        // A stale, replaced probe must never clear a newer hosting association.
        let newerProbe = MenuWindowProbe.ProbeView(owner: menuOwner)
        menu.contentView?.addSubview(newerProbe)
        replacement.contentView = NSView()
        require(menuOwner.window === menu, "Detaching an old probe must preserve the new hosting window")
        menu.contentView = NSView()
        require(menuOwner.window == nil, "Current probe detach must clear association")
        // Close the last visible window after launch as well, then check survival.
        _ = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            dashboard.makeKeyAndOrderFront(nil)
            dashboard.close()
        }
        // Launch notification invokes the real delegate's idle-termination opt-out.
        _ = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { _ in
            require(launchObserved, "LaunchServices must deliver the application launch notification")
            require(ProcessInfo.processInfo.automaticTerminationSupportEnabled, "Automatic termination support must be enabled before disabling it")
            aliveAfterClose = true
            app.terminate(nil)
        }
        withExtendedLifetime(delegate) { app.run() }
        NotificationCenter.default.removeObserver(terminationObserver)
        NotificationCenter.default.removeObserver(launchObserver)
    }

    static func require(_ condition: Bool, _ message: String) {
        if !condition { fatalError("FAIL: " + message) }
    }
}
