#!/usr/bin/env bash
# Measure the built native App using a temporary bundle identity and local fixture.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:?Usage: measure-app-memory.sh APP LOG_ROOT OUTPUT}"
LOG_ROOT="${2:?Specify a controlled Codex log root}"
OUT="${3:?Specify an output directory}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-memory.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
ditto "$APP" "$WORK/Codex Stats.app"
IDENTIFIER="dev.codexstats.memory-test.$(uuidgen | tr '[:upper:]' '[:lower:]')"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $IDENTIFIER" "$WORK/Codex Stats.app/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$WORK/Codex Stats.app"
xcrun swiftc -swift-version 5 -framework AppKit "$ROOT/Tests/AppMemory/main.swift" -o "$WORK/measure"
"$WORK/measure" "$WORK/Codex Stats.app" "$LOG_ROOT" "$OUT"
