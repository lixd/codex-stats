# Design

Keep existing SwiftUI MenuBarExtra and dashboard scene. Capture the menu's own NSWindow using a tiny NSViewRepresentable lifecycle probe; close it before invoking the existing openWindow action. Do not use NSApp.keyWindow, because dashboard may already have focus. Own no strong window reference.

Compact MenuPanelView only: 320-point width, smaller header and total, two compact metric rows, leading model with short ranking, condensed diagnostic summary and single footer. Keep exact values in help and existing error/empty states. No changes to global ModelBar or accounting.

AppDelegate explicitly returns false for termination after last-window close. Per Foundation SDK, automaticTerminationSupportEnabled=false has no effect; use disableAutomaticTermination with a resident-app reason. No ProcessInfo activity preventing sleep/App Nap. OS crash/force kill cannot be prevented by this API.

Existing evidence: old running App unified AppKit log set _kLSApplicationWouldBeTerminatedByTALKey=1, no CodexStats crash report found. This is eligibility evidence, not proof of the prior termination cause. Installed App was run from a mounted DMG, advise Applications installation.
