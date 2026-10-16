import Foundation
import CodexStatsCore

// Optional offline verification CLI, independent of the menu bar application.
struct Output: Encodable {
    struct Derived: Encodable {
        let cacheRate: CacheRate
        let cost: CostEstimate
    }
    struct Model: Encodable { let model: String; let usage: TokenUsage; let sessions: Int; let derived: Derived }
    struct Session: Encodable { let id: String; let recordedSessionID: String?; let project: String; let usage: TokenUsage; let models: [Model]; let derived: Derived }
    let total: TokenUsage
    let derived: Derived
    let priceBasis: String
    let priceExclusions: String
    let priceCatalog: PriceCatalog
    let priceSource: String
    let priceVerifiedOn: String
    let recordDerived: [String: Derived]?
    let models: [Model]
    let sessions: [Session]
    let warnings: [String]
    let diagnostics: [ScanDiagnostic]
    let files: Int
    let invalidLines: Int
    let records: [UsageRecord]?
}
do {
    let args = Array(CommandLine.arguments.dropFirst())
    if args.contains("--help") {
        print("Usage: codex-stats-report [LOG_ROOT] [--records] [--prices PATH]\nRead-only offline report. --prices reads an alternate local price table; it never writes prices.")
        exit(0)
    }
    var root: String?, priceURL = PriceCatalogFile.defaultURL
    var index = 0
    while index < args.count {
        let arg = args[index]
        if arg == "--prices" {
            index += 1
            guard index < args.count, !args[index].hasPrefix("--") else { throw PriceCatalogError.invalid("--prices 需要文件路径") }
            priceURL = URL(fileURLWithPath: args[index])
        } else if arg == "--records" { }
        else if arg.hasPrefix("--") || root != nil { throw PriceCatalogError.invalid("未知或重复参数：" + arg) }
        else { root = arg }
        index += 1
    }
    let catalog = try PriceCatalogFile(url: priceURL).load()
    let logRoot = root ?? NSString(string: "~/.codex").expandingTildeInPath
    let report = try CodexLogScanner().scan(homePath: logRoot)
    let now = Date()
    let valuation = ValuationIndex(report: report, catalog: catalog).summary(in: .all, now: now)
    func derived(_ usage: TokenUsage, _ cost: CostEstimate) -> Output.Derived {
        .init(cacheRate: CacheRate(usage: usage), cost: cost)
    }
    func model(_ m: ModelUsage, costs: [String: CostEstimate]) -> Output.Model {
        .init(model: m.model, usage: m.usage, sessions: m.sessionCount,
              derived: derived(m.usage, costs[m.model] ?? CostEstimate(priceVersion: catalog.revision)))
    }
    let total = report.totals(in: .all, now: now)
    let records = args.contains("--records") ? report.records(in: .all, now: now) : nil
    let result = Output(total: total, derived: derived(total, valuation.total),
        priceBasis: catalog.description + "；USD / 百万 Token；所有历史按当前价表折算，非实际扣费", priceExclusions: ReferencePricing.exclusions,
        priceCatalog: catalog, priceSource: "来源见 priceCatalog.entries；自定义价格未经官方核验", priceVerifiedOn: "内置行核验日期见 priceCatalog.entries",
        recordDerived: records.map { Dictionary(uniqueKeysWithValues: $0.map {
            ($0.id, derived($0.usage, .calculate(usage: $0.usage, model: $0.model, catalog: catalog)))
        }) },
        models: report.models(in: .all, now: now).map { model($0, costs: valuation.models) },
        sessions: report.sessions.map { session in
            .init(id: session.id, recordedSessionID: session.recordedSessionID, project: session.project,
                  usage: session.usage(in: .all, now: now),
                  models: session.modelUsage(in: .all, now: now).map { model($0, costs: valuation.sessionModels[session.id] ?? [:]) },
                  derived: derived(session.usage(in: .all, now: now), valuation.sessions[session.id] ?? CostEstimate(priceVersion: catalog.revision)))
        },
        warnings: report.warnings, diagnostics: report.diagnostics, files: report.fileCount, invalidLines: report.invalidLineCount,
        records: records)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(result)); FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
