#!/usr/bin/env python3
"""Compare real old/new scanner CLI outputs on synthetic coverage variations."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("baseline", type=Path)
parser.add_argument("current", type=Path)
args = parser.parse_args()

def event(kind, payload, seconds=0):
    value = {"type": kind, "payload": payload}
    if seconds is not None:
        value["timestamp"] = f"2026-10-15T00:00:{seconds:02d}Z"
    return value

def native(response, turn, seconds, owner="owner", explicit=True):
    payload = {"thread_id": owner, "response_id": response, "model": "synthetic-model",
               "usage": {"input_tokens": 100, "cached_input_tokens": 80,
                         "output_tokens": 20, "reasoning_output_tokens": 10}}
    if explicit:
        payload["turn_id"] = turn
    return event("token_usage_record", payload, seconds)

def counter(turn, seconds):
    return event("event_msg", {"type": "token_count", "turn_id": turn,
        "info": {"last_token_usage": {"input_tokens": 7, "cached_input_tokens": 2,
            "output_tokens": 3, "reasoning_output_tokens": 1}}}, seconds)

base = [event("session_meta", {"id": "owner", "cwd": "/synthetic/differential"})]
for index in range(2):
    t = f"turn-{index}"
    start = index * 10
    base += [event("turn_context", {"turn_id": t, "model": "synthetic-model"}, start),
        event("event_msg", {"type": "task_started", "turn_id": t}, start),
        native(f"response-{index}-a", t, start + 1),
        native(f"response-{index}-b", t, start + 2),
        event("event_msg", {"type": "task_complete", "turn_id": t,
            "duration_ms": 3000, "time_to_first_token_ms": 10}, start + 3)]
variants = {"clean": base}
# OR relevance: own Turn, interval, physical frame range, or unknown timestamp.
for turn in ("turn-0", "other"):
    for seconds in (None, 2, 8, 12):
        for position in (4, len(base)):
            rows = copy.deepcopy(base)
            restored = "turn-0" if position == 4 else "turn-1"
            rows[position:position] = [
                event("turn_context", {"turn_id": turn, "model": "synthetic-model"}, seconds),
                counter(turn, seconds),
                event("turn_context", {"turn_id": restored, "model": "synthetic-model"}, seconds)]
            variants[f"counter-{turn}-{seconds}-{position}"] = rows
for owner in ("owner", "foreign", None):
    for explicit in (False, True):
        for seconds in (None, 2, 8, 12):
            rows = copy.deepcopy(base)
            rows.insert(4, native("extra", "turn-0", seconds, owner, explicit))
            variants[f"native-{owner}-{explicit}-{seconds}"] = rows
rows = copy.deepcopy(base)
rows.insert(5, event("event_msg", {"type": "turn_aborted", "turn_id": "turn-0"}, 2))
variants["aborted"] = rows
results = []
with tempfile.TemporaryDirectory(prefix="codex-stats-differential-", dir="/tmp") as temp:
    for name, rows in variants.items():
        root = Path(temp) / name
        (root / "sessions").mkdir(parents=True)
        path = root / "sessions/case.jsonl"
        path.write_text("".join(json.dumps(row) + "\n" for row in rows))
        for copy_mode in ("single", "archived", "invalid-archived"):
            if copy_mode != "single":
                archive = root / "archived_sessions/case.jsonl"
                archive.parent.mkdir(exist_ok=True)
                archive.write_text(path.read_text() + ("{broken\n" if copy_mode == "invalid-archived" else ""))
            outputs = [json.loads(subprocess.check_output([str(binary.resolve()), str(root), "--records"]))
                       for binary in (args.baseline, args.current)]
            if outputs[0] != outputs[1]:
                raise AssertionError(f"Unexpected differential output for {name}/{copy_mode}")
            results.append({"case": name, "copy": copy_mode, "records": len(outputs[1]["records"]),
                            "total": outputs[1]["total"]["input"] + outputs[1]["total"]["output"]})
print(json.dumps({"result": "PASS", "cases": len(results), "comparison": "full CLI including raw usage, identities, diagnostics and optional timings", "results": results}, indent=2))
