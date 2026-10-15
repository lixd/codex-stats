#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codex-stats-store-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# Separate executable + isolated UserDefaults suite; does not launch or modify the installed app.
xcrun swiftc -O -swift-version 5 -parse-as-library -framework SwiftUI \
  "$ROOT"/Sources/Core/*.swift "$ROOT/Sources/App/UsageStore.swift" "$ROOT/Tests/UsageStore/main.swift" -o "$WORK/test"
"$WORK/test"
