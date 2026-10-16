#!/usr/bin/env python3
"""Create review-only complete-Turn inputs; never reads existing user logs."""
import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("root", type=Path)
parser.add_argument("--counts", nargs="+", type=int, default=[250, 500, 1000, 2000])
parser.add_argument("--without-completion", action="store_true", help="Control: omit task_complete only; preserve the same requests and starts")
args = parser.parse_args()
if any(count < 1 or count > 5000 for count in args.counts):
    raise SystemExit("Turn counts must be between 1 and 5000")
if args.root.exists() and any(args.root.iterdir()):
    raise SystemExit("Refusing to overwrite a nonempty directory")
args.root.mkdir(parents=True, exist_ok=True)
base = datetime(2026, 10, 15, 0, tzinfo=timezone.utc)

def timestamp(value):
    return value.isoformat(timespec="milliseconds").replace("+00:00", "Z")

cases = []
for count in args.counts:
    directory = f"{'requests' if args.without_completion else 'turns'}-{count}"
    folder = args.root / directory / "sessions"
    folder.mkdir(parents=True)
    path = folder / "synthetic-complete-turns.jsonl"
    with path.open("w", encoding="utf-8") as handle:
        def emit(kind, at, payload):
            handle.write(json.dumps({"type": kind, "timestamp": timestamp(at), "payload": payload}, separators=(",", ":")) + "\n")
        emit("session_meta", base, {"id": "synthetic-owner", "cwd": "/synthetic/scale"})
        for index in range(count):
            start = base + timedelta(seconds=3 * index)
            turn = f"turn-{index:05}"
            emit("event_msg", start, {"type": "task_started", "turn_id": turn})
            emit("token_usage_record", start + timedelta(seconds=1), {
                "thread_id": "synthetic-owner", "turn_id": turn, "response_id": f"response-{index:05}",
                "model": "synthetic-model", "usage": {"input_tokens": 100, "output_tokens": 20,
                "cached_input_tokens": 80, "reasoning_output_tokens": 10}})
            if not args.without_completion:
                emit("event_msg", start + timedelta(seconds=2), {"type": "task_complete", "turn_id": turn,
                    "duration_ms": 2000, "time_to_first_token_ms": 100})
    cases.append({"turns": count, "directory": directory, "bytes": path.stat().st_size,
                  "completeTurns": not args.without_completion})
manifest = {"synthetic": "codex-stats-review-scale-v1", "cases": cases}
(args.root / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(json.dumps(manifest, sort_keys=True))
