# Technical design

Authoritative product contract: [Sage + Teal](../../../../../docs/sage-teal-design.md), approved pending before source edits. Baseline source is v0.2.11/build13 including the previous uncommitted audit repairs; see start-hashes.json and start-status.txt. Preserve them.

CPTheme owns a small fixed set of dynamic NSColor providers resolved by NSAppearance (light/dark and high contrast); views consume role colors. No observable theme store, timers, assets compilation or appearance preference. System text colors/native controls remain semantic. Solid white-label buttons use a separate dark-enough action fill rather than a bright dark-mode text accent.

Dashboard chrome uses section/sidebar background; content page uses page background; Surface stays content background. Requests and models use native Table with hidden scroll content background on the content surface, a subtle border and clipping. Model inset style disables alternating row backgrounds; row count never determines an estimated fixed table height. Requests may retain native alternation. Sessions use section background left, page right, content cards and explicit selected fill/border, plus selected accessibility trait.

Expected source ownership: Components.swift, DashboardView.swift, RequestsContent.swift, SessionsContent.swift, MenuPanelView.swift (only solid action fill), Assets/Info.plist. Tests/UIPreview/main.swift extends existing native render harness; no new framework. Main agent owns project documentation and task metadata. Core, UsageStore and AppLifecycle are out of scope.

Data flow remains scanner→report→store summary/rows→presentation. No data aggregation, filters, IDs, preference keys, lifecycle or geometry contracts change. Native tables retain horizontal/vertical scrolling. Reverting only this task's source edits restores prior appearance, no migration required.
