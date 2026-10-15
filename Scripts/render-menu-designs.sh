#!/usr/bin/env bash
# Throwaway native SwiftUI design proposals. Synthetic data only; no user settings or logs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist/menu-designs}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-menu-design.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
APP_SOURCES=()
for SOURCE in "$ROOT"/Sources/App/*.swift; do
  if [[ "$SOURCE" != "$ROOT/Sources/App/CodexStatsApp.swift" ]]; then APP_SOURCES+=("$SOURCE"); fi
done
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "${APP_SOURCES[@]}" "$ROOT/Tests/MenuDesignPrototype/main.swift" -o "$WORK/preview"
"$WORK/preview" "$OUT"
