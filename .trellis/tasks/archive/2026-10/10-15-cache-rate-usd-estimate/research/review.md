# Independent implementation review — cache ratio and USD reference value

2026-10-15. Scope: R18/R19 and T12/T13; no user App or real logs accessed. Reviewer did not modify product code. Root owns baseline/docs/delivery and implementer owns final native harness captures.

## Findings (fixed)

No confirmed product defect requiring a code fix was found. One verification gap was identified: the initial request-detail images showed the top performance/basic-info region, not the new derived fields further down. The implementer added programmatic bottom-region captures and width assertions; final inspection below confirms the new fields are visible. This is a test-evidence gap, not evidence of a product failure.

## Findings (not fixed)

No blocking source finding. Actual mouse hover, VoiceOver speech, keyboard selection in native Picker, real system high-contrast switching, macOS14 runtime and Intel execution remain manual/unexecuted checks; the offscreen host cannot establish them. No memory/scroll smoothness improvement is claimed. The catalog deliberately measures the approved three-price Standard reference value, not actual subscriptions or historical/full API bills.

## Reviewed real paths

- `Sources/Core/UsageValuation.swift`: Foundation-only; cache ratio derives from aggregate input and cache knownness, zero input and unknown cache are separate states. Monetary calculation uses Decimal integer construction and checked NSDecimal arithmetic, exactly matches four approved model IDs, counts reasoning only through output, and treats missing prices/cache splits as uncovered tokens. Output-only bypasses missing-cache rejection; zero usage is actual zero. Encoding emits null amount for unavailable, typed states and version/coverage/reason data.
- The index traverses accepted `sessions[].records` once and stores only session/day/model scalar estimates. Bucket merge retains the known subset of a partially unknown model; range queries merge buckets instead of pricing records. No scanner, persistence, network, timers or extra retained record copies were introduced.
- `Sources/App/UsageStore.swift:20–43,83–86,137–144,170–201`: one published ScanSnapshot holds matching report/index. `didSet` clears any summary constructed by a subscriber during @Published's pre-assignment callback. ScanWorker builds off-main; failed scans retain the prior pair; changed-root results cannot publish and root reset clears both. Sessions share the captured `now` between rows and valuation. Palette changes preserve summary identity and do not scan.
- `Sources/App/Components.swift:72–151`: one ratio/currency formatter and shared semantic views; USD is formatted after sum, micro-USD uses a less-than-cent label, exact help preserves at least8 decimals, partial/unavailable text is visible independently of help. Full price basis/exclusions/version/date/source live in help/AX and Settings. Actual AX speech is not inferred from source annotations.
- Menu/overview/model A/session/request details use the same Core results, with no monetary sort and no new request Table column. Raw cumulative/last_usage sections are not estimated. CLI uses the same index and record calculator with additive derived fields; unavailable cannot encode numeric zero.

## Independent checks

- Compared all task-start product hashes. Scanner, Models.swift, app lifecycle/appearance, install/build scripts, and existing accounting tests are unchanged from task start. Request Table through `RequestDetailView` boundary is byte-identical to the matching prior v0.2.15 source ZIP. Existing dirty workspace was preserved.
- Re-opened the official pricing page in this review. Its Standard short-context rows independently match input/cache/output per-million: sol2/0.10/10, astra10/1/50, luna0.10/0.01/0.50; specialized Standard codex1.75/0.175/14. Source: https://developers.openai.com/api/docs/pricing . The other service tiers are intentionally excluded, as approved.
- Inspected the five added Core test functions: independent hand-calculated four-price oracles, weighted ratio10% rather than average50%, missing versus zero/output-only, exact tiny/large amounts, repeated sums without rounding, explicit arithmetic errors, partial same-model record retention and equality of session/model/direct totals, date range boundaries. Store assertions exercise pre-assignment pair consistency, subsequent cache invalidation, failed refresh/root reset/obsolete root and palette identity.
- Read this turn's completed host Core log (138 tests, no failures), locale formatter log (en_US/zh_CN/fr_FR), Store state log and optimized synthetic scale log. Did not duplicate those expensive completed runs. Synthetic scale measured100000 accepted records/4000 scalar buckets with exactUSD281.2; this is not a real-user or memory benchmark.
- Independently parsed final-cyan/blue native model geometry:22 records each, all44 document widths <= clip. Evidence: `/tmp/codex-stats-cache-usd-20261015/validation/check-model-geometry.json`. Inspected cyan narrow menu/overview/model/session, blue narrow dark model and blue80-model bottom; last `synthetic-model-0` is fully visible. Vertical scrolling remains necessary and deliberate.
- `bash -n` on changed shell harness scripts: PASS. `git diff --check`: PASS. No configured lint command.
- Independent macOS14 full-App typecheck: PASS (exit0, no diagnostics), `/tmp/codex-stats-cache-usd-20261015/validation/check-typecheck.log`.

## Final native evidence / compiler result

The final frozen-product targeted run finished with explicit PASS in all four logs: `targeted-cyan.log`, `targeted-blue.log`, and both `-legacy.log` variants. Two palettes × light/dark ×950/1120 model widths × overlay/legacy fit remain within their actual clip widths; complete prices are now under the top-right model total, while partial/unavailable remains a separate fully visible line. Initial broader matrix is retained as regression evidence; final targeted captures establish the latest placement.

Independently inspected `targeted-cyan/valuation-models-950-light.png` and the newly generated bottom-region images: known (`80.0%`, less-than-cent), missing cache (`未完整记录`, `无法估算` and110 uncovered Token), unknown model (known0.0% cache but unavailable price and100 uncovered Token), plus `targeted-blue/end-valuation-request-micro-dark.png` (true0.0% cache and nonzero less-than-cent USD). Text is visible and not cropped in the420×600 host. Bottom screenshots prove programmatic native scrolling/rendering of the derived fields, not real trackpad/VoiceOver/hover interaction.

Conclusion: no confirmed code defect or unresolved blocker within the approved scope. Independent typecheck, shell syntax and whitespace checks pass. Existing completed138-test/formatter/Store/native runs provide the task regression results; reviewer did not claim a second execution of them.
