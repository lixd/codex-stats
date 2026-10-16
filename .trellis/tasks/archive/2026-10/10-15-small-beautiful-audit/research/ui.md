# UI / interaction / lifecycle audit

Reviewed current v0.2.10 / build 12 source at audited HEAD 11f2a93. This review changed no product files and operated on no running user App. It read AGENTS, Trellis workflow/task artifacts, current design/requirements/UI/data documents and verification history. Historical PASS claims below are not counted as this audit's execution. Parent owns new test execution and final synthesis.

## Actual state and lifecycle

- `CodexStatsApp.swift:8–25`: one StateObject UsageStore shared by MenuBarExtra.window and single dashboard Window; dashboard minimum 950×630 (`DashboardView.swift:59`), default 1120×760.
- `UsageStore.swift:97–115,132–155`: initial scan, weak-capture repeating Timer, serial worker actor, coalesced pending refresh; failure preserves successful report/time; root change clears display and discards results for other paths. No evidence for unbounded concurrent scanning from this source pass.
- `AppLifecycle.swift:5–25,29–62`: automatic termination opt-out, earliest same-bundle process retained, last-window-close returns false; precise weak menu-host owner closes its own window before opening analysis. Existing v0.2.8 fixes are present. Do not report those repaired behaviors as new defects.
- `DashboardView.swift:28,42–53`: navigation is local view state; each content page owns its search/sort/selection. `MenuPanelView.swift:152–155` opens/activates dashboard without assigning a navigation destination. Current UI contract explicitly describes diagnostics using this same action; lack of deep linking alone is not an implementation defect.
- Request list computes one row array, selects a row from that filtered array, and suppresses detail when it is absent. Close × and Esc handlers exist (`RequestsContent.swift:108–126,150–153`). Copies only real Session/response IDs (`:166–173,260–264`). Sessions real ID display/search/copy are fixed (`SessionsContent.swift:30,113,155–164,217`); no repeat identity-copy bug.

## New evidence inspected

Parent executed current native synthetic previews under `/tmp/codex-stats-audit-20261015/previews`. This reviewer visually inspected:

- `models-950-light.png`: native model rows render known/unknown values; long name is truncated with source-backed help. At minimum width, the total column header is at the right edge and its values are outside the initial viewport.
- `models-1120-dark.png`: same data, all eight columns visible and unknown fields readable.
- `menu-light.png`: B layout, long model name and unknown fields legible; exactly 3 warnings/errors and 1 information item for the fixture.
- `menu-error-light.png`: failed first scan correctly shows no usage, error (two lines plus help), analysis and Quit controls without clipping.
- Parent independently inspected `inspector-950-light.png` and reported the initial table viewport contains identity/time columns while Token columns require horizontal scrolling; no runtime scroll or click claim.

Prepared but did not run a copied supplemental harness at `/var/folders/r5/vby20fm56t3g3bhydvcn897h0000gn/T/codexstats-ui-audit-qjfn5sxq/{main.swift,render.sh}`. It adds sessions 950/1120×630, overview950×630 and valid-report-then-failed-refresh Models/Sessions captures, using only the original script's guarded `codexstats-preview.*` synthetic root. Parent may run it serially if useful; preparation is not evidence of execution. Reproducible source generator: `research/prepare-ui-preview.py REPO OUTPUT_WORK_DIRECTORY` (copies the current harness/runner and makes no product edits).

## Findings for final synthesis

### UI-1 — Analysis pages lose scan-integrity and failure details (P2, confirmed source/render gap; R11/T08)

**Impact.** Models and Sessions can display incomplete successful scans without any local warning/diagnostic entry. On a later whole-scan failure they keep valid old data, but show only the sidebar's generic “读取失败”; the actual reason is unavailable on that page. A user judging model/session consumption cannot tell which logs were omitted without first knowing to navigate to Overview, Requests or Settings. This is not a claim that all errors are globally hidden.

**Evidence.** `DashboardView.swift:95–106` derives status/color solely from `errorMessage`, not `report.diagnostics`; partial-success warnings therefore remain green “本地数据已连接”. Shared header `:116–153` renders refresh metadata but no diagnostic/error surface. Models body `:313–354` has neither StatusBanner nor DiagnosticSummary. Sessions body `SessionsContent.swift:44–82` has neither; its only banner (`:214–215`) is the selected session's inheritance warning. Overview (`DashboardView.swift:232–233`), Requests (`RequestsContent.swift:68–69`) and Settings (`SessionsContent.swift:290–291`) each implement their own status UI. Current native synthetic fixture visibly has “3 条警告 / 错误 · 1 条信息” in `menu-light.png`, while `models-950-light.png` has a green connected state and no warning. `docs/ui-design.md:190,195` describes an analysis-window error banner and folded diagnostics as general states; implementation is narrower.

**Trigger/reproduce.** Load a synthetic valid session plus an invalid JSON file (existing render fixture does this), open Models/Sessions and compare the same report's menu diagnostic count. For failure-after-success, temporarily rename the owned fixture directory then call refresh; preserve root string and previous report, unlike updateRoot which intentionally clears it. Restore and refresh to check recovery. Menu diagnostic action uses the same openAnalysis route (`MenuPanelView.swift:101–112,152–155`), so if the existing dashboard remains on one of these pages it does not expose more detail; runtime navigation retention still requires a click test.

**Smallest repair / tradeoff.** Put a single compact scan-status/error surface in the shared dashboard, or make the shared status open one existing diagnostic surface. Keep old successful values and refresh timestamp; do not convert warnings into fake scan failure or discard data. Remove only the duplicated status rendering made obsolete by the chosen design. A shared collapsed surface costs a little vertical space, but avoids three diverging implementations and gives both affected pages an accessible path. The menu can keep its current open behavior if diagnostics become reachable from every page.

**Verification.** Same report fixture across all five pages; whole-scan failure after success; partial successful scan with error severity; restoration; disclosure content and actual menu-to-existing-dashboard click. Update R11 and UI state/layout contract first. Effort S–M (roughly 0.5–1 day including focused UI verification).

### UI-2 — Minimum-width tables hide the key number before optional detail (P2 design suggestion, confirmed layout observation; R06/R08/R09)

**Impact/evidence.** Current model table orders six numeric fields before Total/Session count (`DashboardView.swift:331–344`), with fixed 150 + 6×76 + 44 column widths, a 218pt sidebar and 60pt page inset. At supported 950pt width, total values are outside the initial viewport (`models-950-light.png`); at 1120pt all fit. Request table places total after time/project/model/input/output/cache (`RequestsContent.swift:78–104`); opening the fixed 360pt inspector (`:108–111`) leaves mostly identity columns in view. This makes comparing the record/list with the detail harder.

**Classification.** Native horizontal scrolling is intentional and documented (`docs/ui-design.md` model/request sections). The 360pt inspector and analysis-window redesign are explicitly deferred. Therefore this is not a new regression, clipped-data defect, or approval to redesign the dashboard. It is fresh evidence for a small, bounded design improvement.

**Smallest proposal / tradeoff.** First prototype column priority: put total next to identity, and define a compact initial column set when inspector is open; preserve all other fields through native scrolling and the existing details. If needed, adapt only inspector allocation. Avoid replacing native Table or adding nested horizontal ScrollViews; previous first-column loss was already fixed. Prefer this small measured adjustment over a whole-window visual rewrite.

**Verification.** At 950×630 and 1120×760, before/after opening detail, long model/project names, unknown fields, large M values, light/dark: identity and at least one primary Token amount visible together; all remaining columns reachable by real horizontal scrolling; selection and close retain filters. Effort M (roughly 1–2 days including design/prototype and interaction verification). Value medium; lower priority than correctness/scan failures.

### UI-3 — Finder and scanner normalize multi-directory input differently (P3 confirmed narrow defect; R14/settings reliability)

**Evidence/trigger.** Scanner trims each comma-separated item (`CodexLogScanner.swift:68–72`); Finder uses first raw item with no per-item trim (`SessionsContent.swift:252–255`). Saving `"/tmp/fixture-one , /tmp/fixture-two"` scans valid roots, but Finder targets `"/tmp/fixture-one "` (trailing space). Store only trims the entire value (`UsageStore.swift:118–121`). No user Finder action was performed; the path mismatch is direct source evidence.

**Minimal repair.** Normalize the first item exactly as the scanner does; ideally use one small shared path resolver only if it reduces actual duplication. Observe open failure instead of silently ignoring its Bool result if feedback is included in the approved settings contract. Test pure path resolution with spaces/tilde/multiple roots; no need to automate Finder for this arithmetic. Effort XS (<0.5 day). Real but uncommon; not recommended as a standalone next batch.

## Minor residuals not worth separate priority work

- Requests search still checks `record.sessionID` (`RequestsContent.swift:27`), while display/copy uses recordedSessionID. For missing metadata this searches an internal `unidentified:` grouping key (`CodexLogScanner.swift:124–130,906`) not presented as a true ID. Sessions correctly searches only recordedSessionID. This does not change accounting and is less important than the previously fixed identity ownership/copy problem. Fold into a later focused identity/search consistency pass; use an absent-session_meta synthetic record to test matching its internal key vs true ID. Do not portray all v0.2.10 identity fixes as absent.
- Session detail prints the same compact total twice (`SessionsContent.swift:175–179`); simplifying the second line to a semantic caption is optional polish, not a defect. Models page duplicates page heading + large title; vertical simplification is lower value than keeping useful columns visible.
- Refresh time has no date (`MenuPanelView.swift:130`, `DashboardView.swift:122`), so a manual-refresh user returning another day can mistake its age. Current contract explicitly chooses time-only. Consider relative/stale date only alongside a shared freshness/error design; no extra polling or timer is needed just for a label.

## Required verification gaps (risks, not invented bugs)

- Actual production MenuBarExtra open → analysis → reopen, existing dashboard focus, window close, Quit and ⌘Q have not been exercised by this reviewer. `Tests/MenuLifecycle/main.swift:15–47` uses owned ordinary NSWindows plus real MenuWindowOwner/Probe; it proves exact host ownership/close order, not SwiftUI menu event integration. Its delayed survival is 0.8s (`:69–75`), not sleep/wake or long residency.
- `Tests/AppLifecycle/main.swift:36–53` validates LaunchServices duplicate handling and normal AppKit termination, not clicking the production Quit button. Only an isolated copied bundle identity with synthetic CODEX_HOME is acceptable while the user's app runs.
- Search/model filter/sort, selecting multiple rows, Esc under search focus, close/reopen selection and clipboard exactness need a targeted real native interaction pass. Source handlers exist; screenshots do not prove event delivery.
- Sidebar is plain Buttons (`DashboardView.swift:75–91`); session list is ScrollView/LazyVStack Buttons (`SessionsContent.swift:59–67`), not a native List selection model. Explicit selected accessibility traits and arrow-key selection are absent in source. Treat keyboard/VoiceOver operation and selected-state announcements as unverified, not a proven inaccessible UI. Test with full keyboard access/VoiceOver; add labels/selection traits or minimal native List behavior only where failure is observed.
- Current preview harness has known/unknown timing assertions and menu fitting-width checks (`Tests/UIPreview/main.swift:140–145`) but table captures mainly assert that a bitmap can be generated (`:147–154`). No evidence of row hit-testing, scroll reachability, accessible label correctness or all-text visibility. Existing loops cover Models/Requests/inspector (`:53–67`) but not Sessions/Settings at minimum height. The supplemental harness only addresses static coverage if executed.
- macOS14 actual hardware, Intel, long residence/sleep-wake and VoiceOver remain unverified; historical VERIFICATION explicitly acknowledges them. Do not count them as failures or repeat them as repaired.

## Keep / defer

Keep B menu at its implemented 288pt/current hierarchy, shared summary, real-ID separation, native Table scrolling and menu ownership/residency design. No evidence justifies more decoration, a new theme system, custom Table, login item/daemon, extra polling, or global navigation rewrite. Immediate UI effort is best spent on trustworthy scan status; compact table priority can be a bounded follow-up after user design approval. Low-frequency Finder normalization and small copy/search feedback are appropriate only in an already scoped polish batch.
