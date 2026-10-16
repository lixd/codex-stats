#!/usr/bin/env bash
# Synthetic isolated native test host; never launches or modifies the installed App.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:?Output directory required}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-price-ui.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP_SOURCES=()
for SOURCE in "$ROOT"/Sources/App/*.swift; do
  if [[ "$SOURCE" != "$ROOT/Sources/App/CodexStatsApp.swift" ]]; then APP_SOURCES+=("$SOURCE"); fi
done
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "${APP_SOURCES[@]}" "$ROOT/Tests/PriceManagement/main.swift" -o "$WORK/preview"
for PALETTE in cyan blue; do
  "$WORK/preview" "$OUT/$PALETTE" "$PALETTE"
  "$WORK/preview" "$OUT/$PALETTE-legacy" "$PALETTE" --legacy -AppleShowScrollBars Always
done
