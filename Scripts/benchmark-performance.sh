#!/usr/bin/env bash
# Synthetic-only workload: creates ~350 MB under WORK; never point WORK/fixture at real logs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-$(mktemp -d "${TMPDIR:-/tmp}/codex-stats-performance.XXXXXX")}"
CORE="${2:-$ROOT/Sources/Core}"
LABEL="${3:-current}"
BASELINE="${4:-}"
mkdir -p "$WORK"
if [[ ! -f "$WORK/fixture/manifest.json" ]]; then
  python3 "$ROOT/Tests/Performance/generate.py" "$WORK/fixture"
fi
# The harness mutates only its generated fixture for a controlled append, then restores it.
# Never pass actual sessions/archived_sessions as WORK/fixture.
xcrun swiftc -O -swift-version 5 "$CORE"/*.swift "$ROOT/Tests/Performance/main.swift" -o "$WORK/$LABEL-benchmark"
if ! /usr/bin/time -l "$WORK/$LABEL-benchmark" "$WORK/fixture" "$WORK/$LABEL" 2> "$WORK/$LABEL-memory.txt"; then
  cat "$WORK/$LABEL-memory.txt" >&2
  exit 1
fi
python3 - "$WORK/$LABEL-memory.txt" <<'PYMEMORY'
import re, sys
text = open(sys.argv[1]).read()
for key in ("maximum resident set size", "peak memory footprint"):
    match = re.search(r"(\d+)\s+" + key, text)
    if not match:
        raise SystemExit("Missing macOS memory measurement: " + key)
    print(f"{key}: {int(match[1]) / 1024**2:.2f} MiB")
PYMEMORY
if [[ -n "$BASELINE" ]]; then
  python3 - "$WORK/$BASELINE-snapshot.json" "$WORK/$LABEL-snapshot.json" <<'PYCOMPARE'
import json, sys
with open(sys.argv[1]) as before, open(sys.argv[2]) as after:
    assert json.load(before) == json.load(after), "Pre/post accounting snapshot mismatch"
print("PASS: exact pre/post records, models, days, hours, order and all four periods")
PYCOMPARE
fi
echo "Aggregate timings and synthetic correctness snapshot: $WORK/$LABEL-{metrics,snapshot}.json"
