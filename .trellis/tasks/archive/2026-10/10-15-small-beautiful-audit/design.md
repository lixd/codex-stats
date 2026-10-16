# Review design, not a product design change

The authoritative product baseline remains docs/design.md, requirements.md, ui-design.md, ui-design-b.md and data-design.md. VERIFICATION.md and the archived refinement task are historical evidence only. B menu, recorded identity separation and bounded presentation summary are already implemented. Analysis-window redesign is deferred, not an approved geometry specification.

Use three independent static-review tracks: accounting, resource/data flow, UI/lifecycle. Reviewers own only their research notes. The primary reviewer owns reproducible checks, delivery review, synthesis and cross-checking findings. Temporary harnesses and generated synthetic inputs live outside product paths; retain useful small harnesses under this review task for reproducibility. Avoid concurrent CPU-heavy benchmarks. No network, installs, running-user-App mutations or real-log input is required.

Evidence hierarchy: deterministic counterexample against current source; current executed tests/measurements; direct code/layout observation; risk awaiting dynamic verification; optional design improvement. An absence of a test is not itself proof of a product bug. Current RSS, current physical footprint, lifetime peak footprint/max RSS and virtual size are separate metrics. A static rendered view is not proof of clicks, keyboard or VoiceOver.

Report references source at the audited HEAD; proposals do not modify requirements or claim implementation approval. Maintain a coverage matrix and exclude known repaired findings before ranking.
