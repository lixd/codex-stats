#!/usr/bin/env bash
# Check the App's real formatter without moving display concerns into Core.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-display.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "$ROOT/Sources/App/Components.swift" \
  "$ROOT/Tests/TokenDisplay/main.swift" -o "$WORK/check"
for LOCALE in en_US zh_CN fr_FR; do
  "$WORK/check" -AppleLocale "$LOCALE"
done
