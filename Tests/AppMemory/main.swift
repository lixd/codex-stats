import AppKit

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "AppMemory", code: 1,
        userInfo: [NSLocalizedDescriptionKey: message]) }
}

func measure() throws {
    // Launch only the temporary, uniquely identified copy made by the memory script.
    let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let root = CommandLine.arguments[2]
    let output = URL(fileURLWithPath: CommandLine.arguments[3])
    let identifier = Bundle(url: appURL)!.bundleIdentifier!
    try require(identifier.hasPrefix("dev.codexstats.memory-test."), "Unexpected test bundle identity")
    try require(NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty,
        "Test bundle is already running")
    let process = Process()
    process.executableURL = appURL.appendingPathComponent("Contents/MacOS/CodexStats")
    var environment = ProcessInfo.processInfo.environment
    environment["CODEX_HOME"] = root
    process.environment = environment
    try process.run()
    defer {
        if process.isRunning {
            NSRunningApplication(processIdentifier: process.processIdentifier)?.terminate()
            let deadline = Date().addingTimeInterval(10)
            while process.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            if process.isRunning { fputs("FAIL: temporary App did not terminate during cleanup\n", stderr) }
        }
        UserDefaults.standard.removePersistentDomain(forName: identifier)
    }

    func wait(_ seconds: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            try require(process.isRunning, "Temporary memory-test App exited early")
            RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.1)))
        }
    }

    for (delay, label) in [(10.0, "cold-10s"), (25.0, "after-refresh-35s")] {
        try wait(delay)
        let measurement = Process()
        measurement.executableURL = URL(fileURLWithPath: "/usr/bin/vmmap")
        measurement.arguments = ["-summary", String(process.processIdentifier)]
        let pipe = Pipe()
        measurement.standardOutput = pipe
        try measurement.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        measurement.waitUntilExit()
        try require(measurement.terminationStatus == 0, "vmmap failed")
        try data.write(to: output.appendingPathComponent(label + ".txt"))
        print(label + ":")
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") where line.contains("Physical footprint") {
            print(line)
        }
        fflush(stdout)
    }
    try require(NSRunningApplication(processIdentifier: process.processIdentifier)?.terminate() == true,
        "Temporary App refused normal termination")
    let deadline = Date().addingTimeInterval(10)
    while process.isRunning && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    try require(!process.isRunning, "Temporary App failed to terminate normally")
    print("PASS: built native App measured at 10/35 seconds; only the test-owned instance terminated")
}

do { try measure() }
catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
