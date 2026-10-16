# Token Display Contract

## Scope

Token amounts in the native App share `abbreviated` from `Sources/App/Components.swift`. Chart axes and TokenDetails must use it too. Do not use Charts automatic number labels or locale-dependent `compactName`: Chinese locales produce 万/亿 and older defaults can produce scientific notation.

## Signatures and Units

```swift
func abbreviated(_ value: Int64, known: Bool = true) -> String
func abbreviated(_ value: Double) -> String
func detailedNumber(_ value: Int64, known: Bool = true) -> String
```

- K = 1,000; M = 1,000,000. Keep M above one billion; no B suffix.
- M uses up to two fractional digits; K uses up to one. Trim trailing zeros.
- Display integers below 10,000 without magnitude abbreviation. Preserve fractional Double chart ticks.
- Promote values >=999,950 to M so rounding does not display 1000K.
- Compact display fixes the locale to en_US_POSIX. Exact `detailedNumber` may use local grouping and never abbreviates or converts the Int64 to Double.
- Missing cache/reasoning values must display 未完整记录, including in help text; zero is an actual known value.
- Display rounding never feeds back into Core counters, date buckets or JSON.

## Cases

| Input | Compact output |
|---|---|
| 0 / 0.5 | 0 / 0.5 |
| 563,240 | 563.2K |
| 999,949 / 999,950 | 999.9K / 1M |
| 40,000,000 | 40M |
| 109,946,996 | 109.95M |
| 1,000,000,000 | 1000M |
| any Int64, known=false | 未完整记录 |

## Exact Values and Verification

TokenDetails uses Chinese field labels (input, cached input, uncached input, output, reasoning, total) and compact text with `.help(detailedNumber(...))`; menu footers, session headings and list totals also use compact text with exact help. MetricTile requires an explicit field-specific semantic caption (for example input includes cached input); do not repeat the main amount in its caption. The main number carries exact-value help. An unknown MetricTile caption names its actual field, never a hardcoded cache explanation. The B menu uses a range-aware total and a 2-by-2 grid; unknown cache/reasoning remains 未完整记录 rather than zero. Original metering detail and CLI keep integer fields. The chart Double overload avoids converting fractional ticks to Int64 or overflowing large ticks.

Run `./Scripts/test-token-display.sh` to test the App's real implementation in en_US, zh_CN and fr_FR without moving UI concerns into Core. Use `./Scripts/render-ui-previews.sh` for today's and 7-day native light/dark charts with synthetic data. Static rendering does not verify hovering or clicking; report that limit explicitly. Keep the existing Core tests green.

Wrong: `tokens.formatted(.number.notation(.compactName))` on a Token axis.

Correct: `Text(abbreviated(tokens))` plus an exact-value path where the component displays amounts.

## Derived metrics (v0.2.16)

`CacheRateText` and `CostEstimateText` in Components.swift are the only shared display paths. CacheRate uses aggregate counters: known one-decimal percent, noInput `—`, incomplete `未完整记录`; help and AX include exact numerator/denominator. Never average displayed percentages.

`dollars(_ value: Decimal)` rounds with NSDecimalRound to two decimals, then groups the decimal string with fixed USD `$`, comma and period. Do not convert money to Double or rely on NumberFormatter(NSDecimalNumber) for rounding: the actual half-cent test exposed different behavior. A positive value below0.01 shows `< $0.01`; real zero shows `$0.00`. Exact help preserves at least8 places without discarding smaller digits.

Complete estimates use API-equivalent reference language; partial estimates visibly state subtotal and uncovered Tokens/reasons; unavailable never shows numeric zero, even in help/AX or CLI. Include version/date/basis/exclusions in help and accessible semantics. Menu288, model950/1120 with both palettes/light/dark/legacy scrollers must fit; preserve Token primary hierarchy and never add request Table columns. Static captures establish rendering, not actual VoiceOver/hover. Run formatter/Store/native gates and Core tests defined in [derived usage](../backend/derived-usage.md).
