import Foundation

public enum PriceCatalogError: LocalizedError {
    case invalid(String)
    case unavailable(String)
    public var errorDescription: String? {
        switch self {
        case .invalid(let message): return "价格配置无效：" + message
        case .unavailable(let message): return "价格配置无法读写：" + message
        }
    }
}

/// Persist decimal strings, preserving exact prices and provenance without binary floating point.
public struct ModelPrice: Codable, Equatable, Sendable, Identifiable {
    public enum Source: String, Codable, Sendable { case builtIn, custom }
    public var id: String { model }
    public let model: String
    public let input: String
    public let cachedInput: String
    public let output: String
    public let source: Source
    public let sourceURL: String?
    public let verifiedOn: String?
    public let price: ReferencePrice
    public init(model: String, input: String, cachedInput: String, output: String,
                source: Source = .custom, sourceURL: String? = nil, verifiedOn: String? = nil) throws {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, model != "Unknown model" else {
            throw PriceCatalogError.invalid("需要日志中的精确模型名称，未知模型不能猜价")
        }
        self.model = model
        self.input = try Self.normalized(input, field: "输入价")
        self.cachedInput = try Self.normalized(cachedInput, field: "缓存输入价")
        self.output = try Self.normalized(output, field: "输出价")
        price = ReferencePrice(input: try Self.decimal(self.input), cachedInput: try Self.decimal(self.cachedInput), output: try Self.decimal(self.output))
        if source == .builtIn {
            guard [ReferencePricing.source, ReferencePricing.changelogSource].contains(sourceURL ?? ""),
                  verifiedOn?.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil else {
                throw PriceCatalogError.invalid("内置价格缺少来源或核验日期")
            }
        }
        self.source = source; self.sourceURL = sourceURL; self.verifiedOn = verifiedOn
    }
    public static func decimal(_ text: String) throws -> Decimal {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: "^[0-9]+(?:\\.[0-9]+)?$", options: .regularExpression) != nil else {
            throw PriceCatalogError.invalid("请填写非负十进制数（小数点使用 .）")
        }
        let digits = value.filter { $0 != "." }.drop(while: { $0 == "0" }).reversed().drop(while: { $0 == "0" })
        guard digits.count <= 38, value.count <= 256,
              let result = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN,
              result > 0 || !value.contains(where: { $0 >= "1" && $0 <= "9" }) else {
            throw PriceCatalogError.invalid("数值超出 Decimal 精度或范围（最多38位有效数字）")
        }
        return result
    }
    private static func normalized(_ text: String, field: String) throws -> String {
        do { _ = try decimal(text); return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        catch PriceCatalogError.invalid(let message) { throw PriceCatalogError.invalid(field + "：" + message) }
    }
    // Never trust a decoded file merely because its JSON shape is correct.
    private enum CodingKeys: String, CodingKey { case model, input, cachedInput, output, source, sourceURL, verifiedOn }
    public init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(model: b.decode(String.self, forKey: .model), input: b.decode(String.self, forKey: .input),
                      cachedInput: b.decode(String.self, forKey: .cachedInput), output: b.decode(String.self, forKey: .output),
                      source: b.decode(Source.self, forKey: .source), sourceURL: b.decodeIfPresent(String.self, forKey: .sourceURL),
                      verifiedOn: b.decodeIfPresent(String.self, forKey: .verifiedOn))
    }
}

public struct PriceCatalog: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let revision: String
    public let entries: [ModelPrice]
    private let byModel: [String: ModelPrice]
    public var containsCustomPrices: Bool { entries.contains { $0.source == .custom } }
    public var description: String { entries.isEmpty ? "本地参考价（空表）" : containsCustomPrices ? "本地参考价（含自定义）" : "本地参考价（内置标准价）" }
    public init(entries: [ModelPrice], revision: String = UUID().uuidString) throws {
        guard Set(entries.map(\.model)).count == entries.count, !revision.isEmpty else {
            throw PriceCatalogError.invalid("模型重复或缺少修订号")
        }
        schemaVersion = 1; self.revision = revision; self.entries = entries.sorted { $0.model < $1.model }
        byModel = Dictionary(uniqueKeysWithValues: entries.map { ($0.model, $0) })
    }
    public static let builtIn: PriceCatalog = try! PriceCatalog(entries: ReferencePricing.prices.map { model, price in
        try! ModelPrice(model: model, input: NSDecimalNumber(decimal: price.input).stringValue,
                        cachedInput: NSDecimalNumber(decimal: price.cachedInput).stringValue,
                        output: NSDecimalNumber(decimal: price.output).stringValue, source: .builtIn,
                        sourceURL: ReferencePricing.source(for: model), verifiedOn: ReferencePricing.verifiedOn)
    }, revision: ReferencePricing.version)
    public func entry(for model: String) -> ModelPrice? { byModel[model] }
    public func setting(_ entry: ModelPrice) throws -> PriceCatalog {
        try PriceCatalog(entries: entries.filter { $0.model != entry.model } + [entry])
    }
    public func removing(_ model: String) throws -> PriceCatalog {
        try PriceCatalog(entries: entries.filter { $0.model != model })
    }
    /// Deliberate import only: loading an existing snapshot never merges defaults.
    public var missingNewBuiltIns: [ModelPrice] {
        Self.builtIn.entries.filter { ReferencePricing.newModels.contains($0.model) && byModel[$0.model] == nil }
    }
    public func addingNewBuiltIns() throws -> PriceCatalog {
        try PriceCatalog(entries: entries + missingNewBuiltIns)
    }
    public func candidates(observedModels: Set<String>) -> [String] {
        observedModels.subtracting(entries.map(\.model)).filter { $0 != "Unknown model" }.sorted()
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, revision, entries }
    public init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        guard try b.decode(Int.self, forKey: .schemaVersion) == 1 else { throw PriceCatalogError.invalid("不支持的文件版本") }
        try self.init(entries: b.decode([ModelPrice].self, forKey: .entries), revision: b.decode(String.self, forKey: .revision))
    }
}

public struct PriceCatalogFile: Sendable {
    public let url: URL
    public init(url: URL = Self.defaultURL) { self.url = url }
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Codex Stats/prices.json")
    }
    public func load() throws -> PriceCatalog {
        do { return try JSONDecoder().decode(PriceCatalog.self, from: Data(contentsOf: url)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return .builtIn }
        catch { throw PriceCatalogError.unavailable(error.localizedDescription) }
    }
    public func save(_ catalog: PriceCatalog) throws {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(catalog).write(to: url, options: .atomic)
        } catch { throw PriceCatalogError.unavailable(error.localizedDescription) }
    }
}
