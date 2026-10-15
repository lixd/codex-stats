#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [[ "$(uname -s)" == Darwin ]]; then
  SWIFT_BIN="$(xcrun --find swiftc)"
  TEST_PLUGIN="${SWIFT_BIN%/bin/swiftc}/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  # CLT's incremental package resolver can omit the bundled Testing macro path.
  if [[ -f "$TEST_PLUGIN" ]]; then
    xcrun swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$TEST_PLUGIN" "$@"
  else
    xcrun swift test --disable-xctest "$@"
  fi
else
  swift test --disable-xctest "$@"
fi
