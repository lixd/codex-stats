import Foundation

@main
struct TokenDisplayChecks {
    static func main() {
        let cases: [(Int64, String)] = [
            (0, "0"), (999, "999"), (9_999, "9999"), (10_000, "10K"),
            (10_050, "10.1K"), (563_240, "563.2K"), (999_949, "999.9K"),
            (999_950, "1M"), (999_999, "1M"),
            (1_000_000, "1M"), (1_005_000, "1.01M"), (40_000_000, "40M"),
            (109_946_996, "109.95M"), (400_000_000, "400M"),
            (1_000_000_000, "1000M"), (1_234_567_890, "1234.57M")
        ]
        for (value, expected) in cases {
            require(abbreviated(value) == expected, "\(value): expected \(expected), got \(abbreviated(value))")
            require(abbreviated(Double(value)) == expected, "Chart and integer display disagree for \(value)")
        }
        require(abbreviated(Int64.max) == "9223372036854.78M", "Int64.max must format without truncation or overflow")
        require(abbreviated(0.5) == "0.5", "Fractional axis labels must not truncate to zero")
        require(abbreviated(1.5) == "1.5", "Fractional axis labels must remain distinct")
        require(!abbreviated(Int64.max).contains("E"), "Large amounts must avoid scientific notation")
        require(abbreviated(0, known: false) == "未完整记录", "Missing counters must not display zero")
        require(abbreviated(400_000_000, known: false) == "未完整记录", "Unknown takes priority over magnitude")
        require(detailedNumber(109_946_996).filter(\.isNumber) == "109946996", "Exact hover value must preserve all digits")
        require(detailedNumber(0, known: false) == "未完整记录", "Unknown hover must remain explicit")
        require(cacheRateLabel(TokenUsage(input: 1000, cachedInput: 800)) == "80.0%", "Cache ratio")
        require(cacheRateLabel(TokenUsage(input: 100, cachedInput: 100) + TokenUsage(input: 900)) == "10.0%", "Weighted ratio")
        require(cacheRateLabel(TokenUsage(input: 10)) == "0.0%", "Known zero cache")
        require(cacheRateLabel(TokenUsage()) == "—", "No input")
        require(cacheRateLabel(TokenUsage(input: 10, cachedInputKnown: false)) == "未完整记录", "Unknown cache")
        require(cacheRateHelp(TokenUsage(input: 1000, cachedInput: 800)).contains(detailedNumber(800)), "Exact ratio numerator")
        require(dollars(0) == "$0.00", "Actual zero dollars")
        require(dollars(Decimal(string: "0.0000001")!) == "< $0.01", "Micro dollars must not round to zero")
        require(dollars(Decimal(string: "1234567.895")!) == "$1,234,567.90", "USD grouping and half-up rounding")
        require(dollars(Decimal(string: "0.01")!) == "$0.01", "Cent boundary")
        let exactCost = CostEstimate.calculate(usage: TokenUsage(input: 1000, cachedInput: 800, output: 100), model: "gpt-6.1-sol")
        require(costHelp(exactCost).contains("0.00148000 USD"), "At least eight decimal places in exact help")
        require(costHelp(exactCost).contains(ReferencePricing.version), "Price provenance in help")
        let historical = try! ModelPrice(model: "gpt-6.1-sol", input: "1.9", cachedInput: "0.09", output: "9", source: .builtIn,
                                         sourceURL: ReferencePricing.source, verifiedOn: "2025-01-01")
        let oldCatalog = try! PriceCatalog(entries: [historical], revision: "historical-snapshot")
        let old = CostEstimate.calculate(usage: TokenUsage(input: 100), model: historical.model, catalog: oldCatalog)
        require(costHelp(old).contains("historical-snapshot") && !costHelp(old).contains(ReferencePricing.verifiedOn), "No fixed current verification date on historical catalog")
        let custom = try! ModelPrice(model: "custom-model", input: "2", cachedInput: "0.1", output: "10")
        let customCatalog = try! PriceCatalog(entries: [custom], revision: "custom-snapshot")
        let customCost = CostEstimate.calculate(usage: TokenUsage(input: 100), model: custom.model, catalog: customCatalog)
        require(costHelp(customCost).contains("自定义") && costHelp(customCost).contains("未经官方核验"), "Custom money does not claim official verification")
        let unavailable = CostEstimate.calculate(usage: TokenUsage(input: 100), model: "Unknown model")
        require(costHelp(unavailable).hasPrefix("无法估算金额"), "Unavailable help must not imply zero dollars")
        require(!costHelp(unavailable).contains("0.00000000 USD"), "No fake numeric zero for unavailable")
        print("PASS: \(cases.count) numeric boundaries, shared chart formatting, unknown fields and exact values; locale=\(Locale.current.identifier)")
    }

    private static func require(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
