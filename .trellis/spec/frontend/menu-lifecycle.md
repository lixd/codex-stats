# Menu and resident lifecycle

## Ownership

Keep SwiftUI MenuBarExtra and dashboard scene. MenuWindowProbe captures its own hosting NSWindow; MenuWindowOwner holds it weakly. Close that exact window before activating/opening the dashboard. Never close NSApp.keyWindow, because it can be the unrelated dashboard. Framework reuse and replacement hosting windows must update association correctly.

## Compact presentation

MenuPanelView uses the production B layout in v0.2.10/build12: 288 points wide, 14-point outer padding, 260-point content, 10-point stack spacing, a range-aware total card followed by a 2-by-2 metric grid. Preserve range, all Token categories, leading model, last successful refresh, loading/error and Quit. Refresh and Quit label hit areas are at least 24 points with explicit accessibility labels. Unknown metrics remain explicit, and no successful report must never render a fake zero. Height is content-fitting, never fixed to the preview's 466-point normal state. Compact diagnostic count opens full analysis instead of expanding large source lists in the menu. Shared formatting retains exact values in help. Do not compress the dashboard just to shorten the menu.

## Residency

Assets/Info.plist sets NSSupportsAutomaticTermination=true; AppDelegate disables automatic termination once at launch with the resident-app reason. Foundation SDK says setting support false has no effect. Bundled harness reproduces that the setter alone is insufficient on current host, so keep the Info key. Delegate returns false after the last window closes. This does not prevent sleep or App Nap; explicit Quit, normal process termination and duplicate-instance rejection still work. No login item or restart daemon.

## Verification

Run Scripts/test-menu-lifecycle.sh for native exact-window close ordering, dashboard ownership, reuse/replacement and resident callback behavior in an owned bundled AppKit harness. Run Scripts/test-app-lifecycle.sh only against an isolated bundle identity if the user App is running. Native previews check menu light/dark layout. Harness success is not actual SwiftUI MenuBarExtra mouse interaction proof. Background crashes or OS force-kills are outside this policy; missing crash reports are not proof of absence.
