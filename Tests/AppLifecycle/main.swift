import AppKit

// Exercise real process lifecycle, independently of the UI automation service.
let appURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let bundleID = Bundle(url: appURL)!.bundleIdentifier!

func instances() -> [NSRunningApplication] {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .filter { !$0.isTerminated }
}

func require(_ condition: Bool, _ message: String) {
    if !condition {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

func waitUntil(_ condition: () -> Bool) -> Bool {
    for _ in 0..<100 {
        if condition() { return true }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    return condition()
}

func launch() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-n", appURL.path]
    try! process.run()
    process.waitUntilExit()
    require(process.terminationStatus == 0, "LaunchServices failed")
}

require(instances().isEmpty, "Quit existing copies before running this test")
launch()
require(waitUntil { instances().count == 1 }, "App did not launch")
let original = instances()[0]
defer {
    if !original.isTerminated { original.terminate() }
}
require(original.bundleURL?.standardizedFileURL == appURL, "Unexpected application path")
// Give applicationWillFinishLaunching time to finish before opening another copy.
RunLoop.current.run(until: Date().addingTimeInterval(2))
launch()
RunLoop.current.run(until: Date().addingTimeInterval(2))
require(waitUntil {
    let running = instances()
    return running.count == 1 && running[0].processIdentifier == original.processIdentifier
}, "Duplicate instance remained or replaced the original")
require(original.terminate(), "AppKit rejected normal termination")
require(waitUntil { instances().isEmpty }, "App failed to terminate")
print("PASS: real app launch, duplicate-instance rejection, normal AppKit termination")
