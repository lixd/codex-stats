import Foundation
import CodexStatsCore

// Optional offline verification CLI, independent of the menu bar application.
struct Output: Encodable {
    struct Model: Encodable { let model: String; let usage: TokenUsage; let sessions: Int }
    struct Session: Encodable { let id: String; let project: String; let usage: TokenUsage; let models: [Model] }
    let total: TokenUsage
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
    let root = args.first(where: { $0 != "--records" }) ?? NSString(string: "~/.codex").expandingTildeInPath
    let report = try CodexLogScanner().scan(homePath: root)
    func model(_ m: ModelUsage) -> Output.Model { .init(model: m.model, usage: m.usage, sessions: m.sessionCount) }
    let result = Output(total: report.totals(in: .all), models: report.models(in: .all).map(model),
        sessions: report.sessions.map { .init(id: $0.id, project: $0.project, usage: $0.usage(in: .all), models: $0.modelUsage(in: .all).map(model)) },
        warnings: report.warnings, diagnostics: report.diagnostics, files: report.fileCount, invalidLines: report.invalidLineCount,
        records: args.contains("--records") ? report.records(in: .all) : nil)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(result)); FileHandle.standardOutput.write(Data("\n".utf8))
} catch {
    FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
    exit(1)
}
