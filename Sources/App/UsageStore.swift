#if SWIFT_PACKAGE
import CodexStatsCore
#endif
import Foundation
import SwiftUI

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case seconds30 = 30, minute1 = 60, minutes5 = 300, minutes15 = 900
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .seconds30: return "30 秒"
        case .minute1: return "1 分钟"
        case .minutes5: return "5 分钟"
        case .minutes15: return "15 分钟"
        }
    }
}

private actor ScanWorker {
    private let scanner = CodexLogScanner()
    func scan(_ path: String) throws -> ScanReport { try scanner.scan(homePath: path) }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var report = ScanReport.empty
    @Published private(set) var loading = false
    @Published private(set) var didScan = false
    @Published private(set) var lastSuccessfulRefresh: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var rootPath: String
    @Published var period: UsagePeriod = .today
    @Published var autoRefresh: Bool {
        didSet {
            defaults.set(autoRefresh, forKey: "CodexPulseAutoRefresh")
            configureTimer()
        }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: "CodexStatsRefreshIntervalSeconds")
            configureTimer()
        }
    }
    var hasReport: Bool { lastSuccessfulRefresh != nil }

    private let defaults: UserDefaults
    private let worker = ScanWorker()
    private var timer: Timer?
    private var pendingRefresh = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        rootPath = defaults.string(forKey: "CodexPulseRoot")
            ?? ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? NSString(string: "~/.codex").expandingTildeInPath
        autoRefresh = defaults.object(forKey: "CodexPulseAutoRefresh") as? Bool ?? true
        refreshInterval = RefreshInterval(rawValue: defaults.integer(forKey: "CodexStatsRefreshIntervalSeconds")) ?? .seconds30
        configureTimer()
        refresh()
    }

    private func configureTimer() {
        timer?.invalidate()
        timer = nil
        if autoRefresh {
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(refreshInterval.rawValue), repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
    }

    func updateRoot(_ value: String) {
        let path = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        rootPath = path
        report = .empty
        lastSuccessfulRefresh = nil
        didScan = false
        errorMessage = nil
        defaults.set(path, forKey: "CodexPulseRoot")
        refresh()
    }

    func refresh() {
        guard !loading else { pendingRefresh = true; return }
        loading = true
        errorMessage = nil
        let path = rootPath
        Task {
            do {
                let scanned = try await worker.scan(path)
                if path == rootPath {
                    report = scanned
                    lastSuccessfulRefresh = scanned.refreshedAt
                    didScan = true
                }
            } catch {
                if path == rootPath { errorMessage = error.localizedDescription; didScan = true }
            }
            loading = false
            if pendingRefresh {
                pendingRefresh = false
                refresh()
            }
        }
    }
}
