# Read-only findings — 2026-10-14

## Live memory

Codex Stats v0.2.6 build 8, PID 62326, runs from `/Volumes/Codex Stats 4/Codex Stats.app/Contents/MacOS/CodexStats`. `vmmap -summary` reports current physical footprint 145.5 MiB at the first observation and 131.2 MiB at 20:04, with lifetime peak 1.1 GiB. These are different measurements from RSS or virtual address space. A peak is not proof of a leak; system swap cannot be assigned wholly to this process.

CC Switch v4.0.6 main PID 49202 has current physical footprint 58.2 MiB and lifetime peak 179.2 MiB. This is its main process only: WebKit helpers exist and have not been reliably attributed, so these numbers do not establish total application memory or a controlled comparison.

No installed applications were closed/restarted, settings changed, or user logs written.

## Fixed synthetic scanner baseline

Existing release `final-benchmark` on the generated 39-file / 349,964,213-byte fixture: 7,020 records, 9,043,780 tokens. `/usr/bin/time -l` measured maximum RSS 252,739,584 bytes and peak footprint 829,359,256 bytes. Cold scan 2.815 s, warm scan 52.68 ms. This independent process reproduces a substantial scanner peak without SwiftUI. The fixture is synthetic and is the only input mutated (append then restoration) by the harness.

Scratch experiments identify two contributors: autoreleased JSON decoding objects and FileHandle read buffers. With only a per-line pool, peak footprint was 400.52 MiB. With scoped pools around both read and line decoding, repeated peak footprints were 59.36 / 59.34 MiB. Freshly compiled current-source baseline peaks were 794.63 / 788.27 MiB. Maximum RSS is reported separately: baseline 187.91 / 219.61 MiB, pooled 84.09 / 83.78 MiB. Cold scan pairs were 3.333 / 2.814 s versus 2.862 / 2.782 s. Exact JSON snapshots compare equal across both repetitions (records/order, tokens, models, sessions, dates/hours, four periods and diagnostics). These results demonstrate a scanner allocation-lifetime problem; they do not prove full application peak after a fix or exclude other memory contributors.

All candidate code is isolated in `/tmp/codex-stats-memory-experiment`; product source and running apps remain unchanged. Files `/tmp/codex-stats-memory-{current,pooled-read}[-repeat].time` and corresponding output/snapshot files contain command evidence. Measurements use `/usr/bin/time -l` and are not interchangeable with vmmap live footprint.

## CC Switch timing: installed version, not upstream main

Installed version: 4.0.6. Git tag v4.0.6 resolves to commit `c261126630b3416e67b407da018cc614bbbe84cd`.

Primary source:
- https://github.com/farion1231/cc-switch/blob/c261126630b3416e67b407da018cc614bbbe84cd/src-tauri/src/services/session_usage_codex.rs#L268-L393
- https://github.com/farion1231/cc-switch/blob/c261126630b3416e67b407da018cc614bbbe84cd/src/components/usage/format.ts#L85-L132
- https://github.com/farion1231/cc-switch/blob/c261126630b3416e67b407da018cc614bbbe84cd/src-tauri/src/services/session_usage.rs#L203-L220

The session-log path estimates request duration using event order and timestamps. At the first model output it captures the preceding boundary (user/context/previous usage/tool output). End prefers a token_usage_record whose input/cache/output match last usage. Older layouts use token_count time, or last model output if the usage event was delayed until tools finished. Aborted/new turns reset pending state; duplicate usage snapshots do not finish a new request. Same-flush handling uses a 100 ms slack.

Duration candidates outside 100 ms–1 hour are discarded. Session speed is output tokens / estimated duration including first-token waiting, shown with ≈. Speed requires at least 200 output tokens and estimated duration at least 1 second; otherwise —. Proxy timing has a separate formula excluding known first-token waiting. Screenshot example: 1,308 / 52.9 ≈ 24.7 tok/s → ≈25 tok/s.

This is an explicit estimate, not a request timer encoded in Codex logs. The old rejected experiment in this repo used individual item envelope intervals; that is a different estimator and must not be revived.

## Model layout

ModelsContent in Sources/App/DashboardView.swift uses a bidirectional ScrollView with a fixed 215-point model column, six 98-point metrics and 65-point session count, plus 30-point row padding. Total width 898 points, while a 950-point app window has substantially less available after sidebar/content padding. Screenshot truncation plus excess gap requires testing scroll origin and model column alignment, not just shrinking fonts. Use a single owner of horizontal scrolling and readable, single-line model names with exact full name on hover.
