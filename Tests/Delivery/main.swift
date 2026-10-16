import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "quit", arguments.count == 2 {
    let identifier = arguments[1]
    // This controller can only terminate fixtures created by this test suite.
    guard identifier.hasPrefix("local.codexstats.delivery-test.") else { exit(2) }
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
    for app in apps { guard app.terminate() else { exit(3) } }
    let deadline = Date().addingTimeInterval(5)
    while apps.contains(where: { !$0.isTerminated }) && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    exit(apps.allSatisfy(\.isTerminated) ? 0 : 4)
}

if Bundle.main.object(forInfoDictionaryKey: "DeliveryTestFailLaunch") as? Bool == true { exit(7) }

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let receipt = Bundle.main.object(forInfoDictionaryKey: "DeliveryTestReceipt") as! String
        let contents: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "bundle": Bundle.main.bundleIdentifier!,
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")!,
            "path": Bundle.main.bundleURL.resolvingSymlinksInPath().path
        ]
        try! JSONSerialization.data(withJSONObject: contents).write(to: URL(fileURLWithPath: receipt))
    }
}

let delegate = Delegate()
let app = NSApplication.shared
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
