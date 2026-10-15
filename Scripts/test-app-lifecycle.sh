#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/dist/Codex Stats.app}"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-lifecycle.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun swiftc -swift-version 5 -framework AppKit "$ROOT/Tests/AppLifecycle/main.swift" -o "$TEST_DIR/check"
"$TEST_DIR/check" "$APP"
