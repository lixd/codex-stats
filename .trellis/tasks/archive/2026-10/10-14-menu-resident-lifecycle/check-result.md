# Independent quality check — v0.2.8 / build 10

Status: full-scope quality gate PASS. No blocking implementation or documentation findings.

## Review

- Read PRD, design, implementation plan, frontend index, menu lifecycle and Token display contracts. No Git repository; no commit claimed.
- MenuPanelView alone is compacted to 320 points; shared Token formatter, report accounting, store and dashboard metrics unchanged. Both analysis entry points call the same specific-window handoff.
- MenuWindowOwner weakly references its own hosting window. Probe attachment/replacement and stale detachment handling avoid closing or clearing unrelated dashboard ownership. Closing occurs before the existing openWindow/activate actions.
- AppDelegate opts out of automatic termination, with Info.plist enabling framework support, and returns false after the last window closes. Explicit terminate and the original duplicate-instance logic remain intact. This policy does not prevent crashes, force-kills or sleep.
- Mechanically corrected README menu ranking from three to two models and distinguished menu Quit label from sidebar Quit label.

## Commands independently executed

- `./Scripts/test-menu-lifecycle.sh`: PASS; actual bundled AppKit launch notification, exact-window close order, unaffected dashboard, reused/replaced hosting windows, stale probe association, last-window survival and normal explicit termination. Short test duration does not demonstrate long-term residency.
- `./Scripts/test-token-display.sh`: PASS, 16 boundaries in en_US / zh_CN / fr_FR.
- `bash -n` for menu lifecycle, build, DMG, previews and app lifecycle scripts: PASS.
- `plutil -lint Assets/Info.plist`: PASS.
- `codesign --verify --deep --strict "dist/Codex Stats.app"`: PASS.
- `xcrun vtool -show-build .../CodexStats`: minOS 14.0, SDK 27.0. Release Info.plist inspected: 0.2.8 / build 10.

## Evidence reviewed

- Root Core test output `/tmp/codex-stats-v028-tests.txt`: 114 tests passed, 0 failures. Core was not changed in this task.
- Native menu light/dark images in `/tmp/codex-stats-v028-menu-previews`: compact readable metrics, unknown cache/reasoning, long model truncation, diagnosis, analysis and Quit all visible. Images currently 640×798; renders are static validation, not actual MenuBarExtra clicks.
- Root controlled App memory samples `/tmp/codex-stats-app-memory-v028`: 10 seconds 26.3 MiB current / 30.5 MiB peak; 35 seconds 27.8 / 35.5 MiB. Sampling does not prove scan completion or long-term peak.
- Root DMG verification `/tmp/codex-stats-v028-dmg-check.txt`: CRC verification successful.

## Final release gate

- Reviewed final v0.2.8 VERIFICATION.md, README, requirements and design. Versions, two-model scope, exact-window ownership, resident policy and manual-verification limits match production code.
- Root reports final isolated App lifecycle command `./Scripts/test-app-lifecycle.sh "/tmp/codexstats-v028-lifecycle.iNnNUe/Codex Stats.app"` PASS: actual final release copy with unique bundle ID, original PID retained, duplicate rejected, normal termination. This is root-executed evidence, not a second independent execution or button-click proof.
- Final menu images remain the reviewed `/tmp/codex-stats-v028-menu-previews/menu-{light,dark}.png`; no production UI change after those renders.
- Root checked measured isolated process 70990 AppKit TAL eligibility=0. This supports the explicit automatic-termination policy; it does not establish the cause of old-version disappearance or guarantee long-term survival.
- No code blockers found. Source archive packaging is root closeout work after this gate. Actual SwiftUI MenuBarExtra mouse interaction, long-term residency observation and macOS 14 physical-device acceptance remain manual; final delivery must preserve those limits.

