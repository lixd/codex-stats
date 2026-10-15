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
        print("PASS: \(cases.count) numeric boundaries, shared chart formatting, unknown fields and exact values; locale=\(Locale.current.identifier)")
    }

    private static func require(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
    }
}
