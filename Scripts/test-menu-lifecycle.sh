#!/usr/bin/env bash
# Test native hosting-window ownership and resident delegate without UI automation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-menu-lifecycle.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/MenuLifecycle.app"
mkdir -p "$APP/Contents/MacOS"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.codexstats.menu-test.$(uuidgen)</string>
<key>CFBundleExecutable</key><string>check</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>NSSupportsAutomaticTermination</key><true/>
</dict></plist>
PLIST
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework SwiftUI \
  "$ROOT/Sources/App/AppLifecycle.swift" "$ROOT/Tests/MenuLifecycle/main.swift" -o "$APP/Contents/MacOS/check"
codesign --force --sign - --timestamp=none "$APP"
open -W -n "$APP" --stdout "$WORK/output.txt" --stderr "$WORK/error.txt"
cat "$WORK/output.txt"
if ! rg -q '^PASS:' "$WORK/output.txt"; then
  cat "$WORK/error.txt" >&2
  exit 1
fi
