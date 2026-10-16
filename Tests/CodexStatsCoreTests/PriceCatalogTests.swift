import Foundation
import Testing
@testable import CodexStatsCore

@Test func priceCatalogDefaultsPersistenceAndDeletedBuiltinDoNotResurrect() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = PriceCatalogFile(url: root.appendingPathComponent("prices.json"))
    #expect(try file.load() == .builtIn)
    #expect(!FileManager.default.fileExists(atPath: file.url.path))
    let withoutSol = try PriceCatalog.builtIn.removing("gpt-6.1-sol")
    try file.save(withoutSol)
    let loaded = try file.load()
    #expect(loaded == withoutSol && loaded.entry(for: "gpt-6.1-sol") == nil)
    #expect(loaded.candidates(observedModels: ["gpt-6.1-sol", "Unknown model", "old-model", "gpt-6-luna"]) == ["gpt-6.1-sol", "old-model"])
    // A persisted historical built-in snapshot survives future compiled default changes.
    let historical = try ModelPrice(model: "gpt-6.1-sol", input: "1.9", cachedInput: "0.09", output: "9",
                                    source: .builtIn, sourceURL: ReferencePricing.source, verifiedOn: "2025-01-01")
    try file.save(PriceCatalog(entries: [historical], revision: "historical-snapshot"))
    #expect(try file.load().entry(for: "gpt-6.1-sol") == historical)
    let empty = try PriceCatalog(entries: [])
    try file.save(empty)
    #expect(try file.load().entries.isEmpty)
    let custom = try ModelPrice(model: "gpt-6.1-sol", input: "3", cachedInput: "0", output: "11")
    let added = try loaded.setting(custom)
    try file.save(added)
    #expect(try file.load().entry(for: custom.model)?.source == .custom)
    #expect(added.revision != withoutSol.revision)
}

@Test func priceFieldsValidateExactNonnegativeDecimalWithoutPartialParsing() throws {
    for bad in ["", " ", "-1", "+1", "1,2", "1.2 USD", "NaN", "Infinity", "1e3", ".1", "1.", String(repeating: "9", count: 39), "0." + String(repeating: "0", count: 129) + "1"] {
        #expect(throws: (any Error).self) { try ModelPrice.decimal(bad) }
    }
    #expect(try ModelPrice.decimal("1." + String(repeating: "0", count: 50)) == 1)
    let price = try ModelPrice(model: "new-exact-id", input: "0", cachedInput: " 0.00000000001 ", output: "999999.123456789")
    #expect(price.price.input == 0 && price.price.cachedInput == Decimal(string: "0.00000000001"))
    #expect(try JSONDecoder().decode(ModelPrice.self, from: JSONEncoder().encode(price)) == price)
    #expect(throws: (any Error).self) { try ModelPrice(model: "Unknown model", input: "1", cachedInput: "1", output: "1") }
    #expect(throws: (any Error).self) { try PriceCatalog(entries: [price, price]) }
}

@Test func catalogRejectsCorruptInvalidAndUnwritableFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = PriceCatalogFile(url: root.appendingPathComponent("prices.json"))
    for text in ["broken", "{}", "{\"schemaVersion\":2,\"revision\":\"x\",\"entries\":[]}", "{\"schemaVersion\":1,\"revision\":\"x\",\"entries\":[{\"model\":\"a\",\"input\":\"-1\",\"cachedInput\":\"0\",\"output\":\"1\",\"source\":\"custom\"}]}"] {
        try Data(text.utf8).write(to: file.url)
        #expect(throws: (any Error).self) { try file.load() }
    }
    let badParent = file.url.appendingPathComponent("nested.json") // parent is a file, deterministically fails even as root.
    #expect(throws: (any Error).self) { try PriceCatalogFile(url: badParent).save(.builtIn) }
    #expect(throws: (any Error).self) { try PriceCatalogFile(url: root).load() }
}

@Test func customAndUnavailableCatalogHaveTruthfulMoneyProvenance() throws {
    let custom = try ModelPrice(model: "new-model", input: "2", cachedInput: "0.1", output: "10")
    let catalog = try PriceCatalog(entries: [custom], revision: "hand-oracle")
    let usage = TokenUsage(input: 1000, cachedInput: 800, output: 100)
    let result = CostEstimate.calculate(usage: usage, model: "new-model", catalog: catalog)
    #expect(result.exactUSD == "0.00148" && result.priceVersion == "hand-oracle" && result.priceSources == [.custom])
    let unavailable = CostEstimate.calculate(usage: usage, model: "new-model", catalog: nil)
    #expect(unavailable.state == .unavailable && unavailable.reasons == [.priceConfigurationUnavailable: 1])
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as! [String: Any]
    #expect(json["priceSources"] as? [String] == ["custom"])
    let zero = try catalog.setting(ModelPrice(model: "new-model", input: "0", cachedInput: "0", output: "0"))
    #expect(CostEstimate.calculate(usage: usage, model: "new-model", catalog: zero).exactUSD == "0")
}
