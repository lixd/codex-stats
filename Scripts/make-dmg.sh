#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build-macos.sh" "$ROOT/dist"
if [[ "$(uname -s)" != "Darwin" ]]; then exit 1; fi
STAGE="$ROOT/dist/dmg-stage"
mkdir -p "$STAGE"
rm -rf "$STAGE"/*
ditto "$ROOT/dist/Codex Stats.app" "$STAGE/Codex Stats.app"
ln -sf /Applications "$STAGE/Applications"
hdiutil create -volname "Codex Stats" -srcfolder "$STAGE" -ov -format UDZO "$ROOT/dist/CodexStats.dmg"
rm -rf "$STAGE"
echo "DMG: $ROOT/dist/CodexStats.dmg"
