import AppKit
import CryptoKit
import Darwin

// Development helper only; it is not bundled with the application.
struct DeliveryError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct AppIdentity: Equatable {
    let identifier: String
    let executable: String
    let version: String
    let build: String

    init(plist: URL) throws {
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil)
        guard let info = value as? [String: Any],
              info["CFBundlePackageType"] as? String == "APPL",
              let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty,
              let executable = info["CFBundleExecutable"] as? String, !executable.isEmpty,
              executable == (executable as NSString).lastPathComponent,
              let version = info["CFBundleShortVersionString"] as? String, !version.isEmpty,
              let build = info["CFBundleVersion"] as? String, !build.isEmpty else {
            throw DeliveryError(message: "App 的身份、版本或可执行文件信息不完整：\(plist.path)")
        }
        self.identifier = identifier
        self.executable = executable
        self.version = version
        self.build = build
    }
}

func appURL(_ path: String) -> URL {
    URL(fileURLWithPath: path).standardizedFileURL
}

func identity(at app: URL) throws -> AppIdentity {
    try AppIdentity(plist: app.appendingPathComponent("Contents/Info.plist"))
}

func checkSeparatePaths(_ source: URL, _ destination: URL) throws {
    let from = source.resolvingSymlinksInPath().path
    let to = destination.resolvingSymlinksInPath().path
    guard from != to, !from.hasPrefix(to + "/"), !to.hasPrefix(from + "/") else {
        throw DeliveryError(message: "来源与目标路径不能相同或互相包含")
    }
}

func checkDestination(_ destination: URL, identity expected: AppIdentity, anyInstance: Bool) throws {
    var entry = stat()
    let exists = lstat(destination.path, &entry) == 0
    if !exists && errno != ENOENT { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    if exists && (entry.st_mode & S_IFMT) == S_IFLNK {
        throw DeliveryError(message: "拒绝替换符号链接：\(destination.path)")
    }
    if exists, try identity(at: destination).identifier != expected.identifier {
        throw DeliveryError(message: "目标属于另一个 App，未替换：\(destination.path)")
    }
    let target = destination.resolvingSymlinksInPath()
    let running = NSWorkspace.shared.runningApplications.first { app in
        !app.isTerminated && ((anyInstance && app.bundleIdentifier == expected.identifier)
            || app.bundleURL?.resolvingSymlinksInPath() == target)
    }
    if let running {
        throw DeliveryError(message: "App 正在运行（PID \(running.processIdentifier)）：\(running.bundleURL?.path ?? expected.identifier)。请手动退出后重试；没有终止该进程。")
    }
}

func validate(_ app: URL) throws -> AppIdentity {
    guard try app.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]).isDirectory == true,
          try app.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
        throw DeliveryError(message: "App 必须是普通目录：\(app.path)")
    }
    let expected = try identity(at: app)
    let executable = app.appendingPathComponent("Contents/MacOS/\(expected.executable)")
    guard FileManager.default.isExecutableFile(atPath: executable.path),
          try executable.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]).isRegularFile == true,
          try executable.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else {
        throw DeliveryError(message: "App 的可执行文件缺失或无效：\(executable.path)")
    }
    let verify = Process()
    verify.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    verify.arguments = ["--verify", "--deep", "--strict", app.path]
    try verify.run()
    verify.waitUntilExit()
    guard verify.terminationStatus == 0 else {
        throw DeliveryError(message: "App 严格签名校验失败，未替换：\(app.path)")
    }
    return expected
}

func executableHash(_ app: URL, identity: AppIdentity) throws -> SHA256.Digest {
    SHA256.hash(data: try Data(contentsOf: app.appendingPathComponent("Contents/MacOS/\(identity.executable)"), options: .mappedIfSafe))
}

func launchAndVerify(_ destination: URL, expected: AppIdentity, hash: SHA256.Digest) throws {
    try checkDestination(destination, identity: expected, anyInstance: true)
    let started = Date()
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    var completed = false
    var launched: NSRunningApplication?
    var launchError: Error?
    NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { app, error in
        launched = app
        launchError = error
        completed = true
    }
    let deadline = Date().addingTimeInterval(15)
    while Date() < deadline && (!completed || (launched?.isFinishedLaunching == false && launched?.isTerminated == false)) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    if let launchError { throw launchError }
    guard completed, let launched, !launched.isTerminated, launched.isFinishedLaunching,
          let launchDate = launched.launchDate, launchDate >= started,
          launched.bundleIdentifier == expected.identifier,
          launched.bundleURL?.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath(),
          launched.executableURL?.resolvingSymlinksInPath() == destination.appendingPathComponent("Contents/MacOS/\(expected.executable)").resolvingSymlinksInPath(),
          try identity(at: destination) == expected,
          try executableHash(destination, identity: expected) == hash else {
        throw DeliveryError(message: "未确认指定路径、身份和版本的进程完成启动：\(destination.path)")
    }
    print("已确认运行：\(destination.path)，v\(expected.version) / build \(expected.build)，PID \(launched.processIdentifier)")
}

do {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 4, args[0] == "check" || args[0] == "publish", args[3] == "build" || args[3] == "install" else {
        throw DeliveryError(message: "用法：app-delivery check INFO_PLIST DESTINATION build|install；或 publish STAGED_APP DESTINATION build|install")
    }
    let destination = appURL(args[2])
    let installing = args[3] == "install"
    if args[0] == "check" {
        let plist = appURL(args[1])
        if plist.deletingLastPathComponent().lastPathComponent == "Contents" {
            try checkSeparatePaths(plist.deletingLastPathComponent().deletingLastPathComponent(), destination)
        }
        try checkDestination(destination, identity: AppIdentity(plist: plist), anyInstance: installing)
    } else {
        let source = appURL(args[1])
        try checkSeparatePaths(source, destination)
        let expected = try validate(source)
        let hash = try executableHash(source, identity: expected)
        try checkDestination(destination, identity: expected, anyInstance: installing)
        let replacing = FileManager.default.fileExists(atPath: destination.path)
        let flags = replacing ? UInt32(RENAME_SWAP) : UInt32(RENAME_EXCL)
        // Both paths must be on the same volume. Unsupported filesystems fail closed.
        guard renameatx_np(AT_FDCWD, source.path, AT_FDCWD, destination.path, flags) == 0 else {
            throw DeliveryError(message: "原子发布失败，目标未替换：\(String(cString: strerror(errno)))")
        }
        print("已发布：\(destination.path)，v\(expected.version) / build \(expected.build)")
        if installing {
            do {
                try launchAndVerify(destination, expected: expected, hash: hash)
            } catch {
                fputs("App 已替换，但启动未确认：\(error.localizedDescription)\n", stderr)
                if replacing { fputs("旧副本保留在：\(source.path)\n", stderr) }
                exit(2)
            }
        }
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
