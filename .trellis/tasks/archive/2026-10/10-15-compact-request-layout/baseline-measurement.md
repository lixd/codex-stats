# Current-turn baseline measurement

2026-10-15; production files unchanged during measurement. Synthetic renderer via temporary copy of UIPreview harness, isolated UUID defaults, prohibited activation, no user App actions. Four native PNGs in `/tmp/codex-stats-compact-requests-20261015/before`; complete stdout/stderr in sibling `before.log`; temporary source `baseline.swift` and renderer `baseline.sh` retained.

| Host | Table height | Native document width | Clip width | Horizontal overflow | Native rows |
|---|---:|---:|---:|---:|---:|
|1120×760, light/dark|459|962|887|75|6|
|950×630, light/dark|329|962|717|245|6|

Widths: 78,95,115,65,58,65,68,65,78,90. Native intercell spacing17pt. Width sum777; document contains185pt additional native spacing/insets. Each screenshot confirms final columns clipped. Table top is254pt visually; temporary logger used bottom-based top calculation47, incorrect for flipped NSHostingView, so that logger value is not used as evidence for top. New logger must branch on host.isFlipped.

User clarified no horizontal scrolling, vertical scrolling required. Seven paired-field columns at narrow widths and native detail sheet are proposed to parent; no dependent implementation until project design is updated.
