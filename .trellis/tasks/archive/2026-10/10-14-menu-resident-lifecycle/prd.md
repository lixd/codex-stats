# Compact menu and resident lifecycle

Approved scope: user requests compact menu, automatic dismissal when opening analysis, and investigating disappearance after some time. Prior instruction authorizes subsequent Trellis tasks. No login launch requested.

## Acceptance
- Compact native menu around 320 points wide; retain all token categories, range selection, leading model, refresh and quit. Avoid duplicated captions and large decorative whitespace.
- Opening analysis dismisses the specific menu hosting window before opening/activating dashboard. Menu remains available for repeated opening; never close an unrelated dashboard.
- Explicitly keep process resident when all windows close and opt out of idle automatic termination; explicit Quit and duplicate-instance rejection remain functional.
- Test native close/handoff order, window ownership, resident policy and repeated operation; build, previews, lifecycle and unaffected Core tests.
- Background disappearance cause remains evidence bounded; no claim that absence of crash logs proves no crash, no infinite restart agent or login item.
