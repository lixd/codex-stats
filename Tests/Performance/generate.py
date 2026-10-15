#!/usr/bin/env python3
"""Deterministic synthetic workload. Never reads real Codex data."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
if root.exists() and any(root.iterdir()):
    raise SystemExit("Refusing to overwrite a nonempty fixture directory")
root.mkdir(parents=True, exist_ok=True)
sessions, records, line_target, byte_target = 39, 7_020, 65_000, 350_000_000
files = []
sums = [dict(input_tokens=0, output_tokens=0, cached_input_tokens=0, reasoning_output_tokens=0) for _ in range(sessions)]
expected = dict(input_tokens=0, output_tokens=0, cached_input_tokens=0, reasoning_output_tokens=0)
line_count = byte_count = 0

def emit(handle, value):
    global line_count, byte_count
    text = json.dumps(value, separators=(",", ":"), ensure_ascii=True) + "\n"
    handle.write(text)
    line_count += 1
    byte_count += len(text)

try:
    for session in range(sessions):
        folder = root / "sessions"
        folder.mkdir(exist_ok=True)
        handle = (folder / f"synthetic-{session:02}.jsonl").open("w")
        files.append(handle)
        emit(handle, {"timestamp": "2026-10-01T00:00:00.000Z", "type": "session_meta", "payload": {
            "id": f"session-{session:02}", "cwd": f"/synthetic/project-{session % 5}", "timestamp": "2026-10-01T00:00:00.000Z"}})
    for index in range(records):
        session = index % sessions
        handle = files[session]
        timestamp = f"2026-10-{8 + index % 7:02}T{index // 7 % 24:02}:{index % 60:02}:{index * 7 % 60:02}.123Z"
        tokens = dict(input_tokens=1_000 + index % 500, output_tokens=20 + index % 40,
                      cached_input_tokens=900 + index % 500, reasoning_output_tokens=(20 + index % 40) // 3)
        model = "model-alpha" if index % 2 == 0 else "model-beta"
        turn = f"turn-{index // (sessions * 20):03}-{session:02}"
        if index // sessions % 20 == 0:
            emit(handle, {"timestamp": timestamp, "type": "turn_context", "payload": {"turn_id": turn, "model": model}})
        for field, value in tokens.items():
            sums[session][field] += value
            expected[field] += value
        emit(handle, {"timestamp": timestamp, "type": "token_usage_record", "payload": {
            "thread_id": f"session-{session:02}", "turn_id": turn, "response_id": f"response-{index:05}",
            "model": model, "usage": tokens, "thread_token_usage": sums[session].copy()}})
        emit(handle, {"timestamp": timestamp, "type": "event_msg", "payload": {"type": "token_count",
            "info": {"total_token_usage": sums[session].copy(), "last_token_usage": tokens}}})
    remaining = line_target - line_count
    # Fill with synthetically generated assistant text, exercising full JSON decode
    # and timestamp paths at representative byte volume. No real prompt is copied.
    template = {"timestamp": "2026-10-14T08:00:00.123Z", "type": "response_item", "payload": {
        "type": "message", "role": "assistant", "content": [{"type": "output_text", "text": ""}]}}
    overhead = len(json.dumps(template, separators=(",", ":"))) + 1
    text_length = (byte_target - byte_count) // remaining - overhead
    template["payload"]["content"][0]["text"] = "S" * text_length
    for index in range(remaining):
        emit(files[index % sessions], template)
finally:
    for handle in files:
        handle.close()
manifest = {"synthetic": "codex-stats-performance-v1", "files": sessions, "records": records, "lines": line_count, "bytes": byte_count, "usage": expected}
(root / "manifest.json").write_text(json.dumps(manifest, sort_keys=True))
print(json.dumps(manifest, sort_keys=True))
