# Proposed design

## Memory

Preserve the streaming parser and serial cache. Scope autoreleased Foundation objects to each read and each decoded line. Retained Frame/ParsedLog values must survive normally; only temporary objects are released. The scratch change is three local replacements in forEachLine, not a scanner rewrite. Account for errors/partial tails and prove output equivalence. Do not add dependencies or full-log buffers.

## Model layout

Use one horizontal-scroll owner and explicit leading alignment. Reduce the oversized first-column space with a readable bounded single-line name column; maintain consistent column dimensions between headers and rows. Validate intrinsic widths and scroll origin in a 950-point host, not only wide previews. Do not rewrite other pages or change aggregation.

## Request estimate, approved

Adapt CC Switch v4.0.6 event-order boundaries to accepted individual response identities rather than attaching an estimate blindly to every token_count. Keep an explicit optional estimate separate from TurnPerformance. At first model output, capture the preceding user/context/tool/previous-usage boundary. Prefer a matching native usage-record timestamp as end. Research fallback handling for delayed legacy notifications; cumulative batches must not receive fabricated per-request timers. Reset incomplete request state at aborted/new turns; don't reuse previous-turn origins.

Cross-copy evidence must preserve native response ownership, deduplication and conflict handling. Ambiguous estimates remain nil. Show estimated duration separately from verified Turn duration; output/estimated seconds includes initial waiting. Reject implausible duration (<100 ms or >1 hour); display rate only with output >=200 and duration >=1 s. These eligibility limits filter evidence; they must not clamp a bad estimate to a plausible speed.

Do not reuse item_started/item_completed envelope intervals, previously shown to yield implausible rates. Do not infer request start from a prior request's timestamp alone when an intervening boundary is missing.

## Change boundary

Expected product files: Core/CodexLogScanner.swift for lifetime/boundary capture, Core/Models.swift for optional estimate, App/RequestsContent.swift for estimate table/detail display, App/DashboardView.swift for model spacing. Focused tests and preview/benchmark harnesses, project docs and Trellis contracts are necessary validation/tracking. Store timer and token arithmetic remain unchanged.
