#!/usr/bin/env python3
"""Read-only accounting audit; compile current Core or pass --binary.

All generated input and build products are temporary synthetic files. Output
reports current behavior, including two known failures; exit 0 means execution
completed, not that product invariants passed.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def usage(i=100, o=10, c=0, r=0):
    return dict(input_tokens=i, output_tokens=o, cached_input_tokens=c, reasoning_output_tokens=r)


def event(kind, payload):
    return dict(type=kind, payload=payload, timestamp="2026-10-15T01:02:00Z")


def count(total=None, last=None):
    info = {k: v for k, v in [("total_token_usage", total), ("last_token_usage", last)] if v is not None}
    return event("event_msg", dict(type="token_count", info=info))


def native(response="response-1", owner="audit-session"):
    return event("token_usage_record", dict(thread_id=owner, turn_id="t1",
        response_id=response, usage=usage(), thread_token_usage=usage()))


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--binary", type=Path, help="Existing CLI built from the audited current source")
args = parser.parse_args()
repo = next(parent for parent in Path(__file__).resolve().parents
    if (parent / "Package.swift").is_file() and (parent / "Sources/Core").is_dir())
meta = event("session_meta", dict(id="audit-session", cwd="/synthetic/audit"))
turn = event("turn_context", dict(turn_id="t1", model="model-A"))
u = usage()
last = count(last=u)
cases = {
    "single_native_notification_control": ([meta, turn, native(), last], 110),
    "repeated_native_last_only": ([meta, turn, native(), last, native(), last], 110),
    "repeated_last_only_after_native": ([meta, turn, native(), last, last], 110),
    "cumulative_growth_control": ([meta, turn, native(), count(u, u), native(), count(usage(200, 20), u)], 220),
    "distinct_response_equal_usage_control": ([meta, turn, native(), last, native("response-2"), last], 220),
    "rejected_owner_replay_control": ([meta, turn, native(owner="foreign"), last, native(owner="foreign"), last], 0),
    "impossible_subset_delta": ([meta, turn, count(usage(100, 100, 0, 0)), count(usage(110, 110, 50, 50))], None),
}
results = []
with tempfile.TemporaryDirectory(prefix="codex-stats-accounting-", dir="/tmp") as tmp:
    base = Path(tmp)
    binary = args.binary.resolve() if args.binary else base / "report"
    if not args.binary:
        main = base / "main.swift"
        main.write_text((repo / "Sources/Report/main.swift").read_text().replace("import CodexStatsCore\n", ""))
        subprocess.run(["swiftc", "-O", "-swift-version", "5",
            str(repo / "Sources/Core/Models.swift"), str(repo / "Sources/Core/CodexLogScanner.swift"),
            str(main), "-o", str(binary)], check=True)
    for name, (lines, correct_total) in cases.items():
        root = base / name
        root.mkdir()
        (root / "case.jsonl").write_text("".join(json.dumps(x) + "\n" for x in lines))
        obj = json.loads(subprocess.check_output([str(binary), str(root), "--records"], text=True))
        total = obj["total"]["input"] + obj["total"]["output"]
        rows = sorted([dict(evidence=row["evidence"], requestID=row.get("requestID"), usage=row["usage"])
            for row in obj["records"]], key=lambda row: (row["evidence"], row["requestID"] or ""))
        result = dict(case=name, actual_total=total, actual_usage=obj["total"], rows=rows,
            warnings=obj["warnings"])
        if correct_total is not None:
            result.update(correct_total=correct_total, correct_total_matches=total == correct_total)
        else:
            result.update(required_behavior="Invalid subset delta must not become a known exact value silently",
                diagnostic_present=bool(obj["warnings"]))
        results.append(result)
print(json.dumps(results, ensure_ascii=False, indent=2, sort_keys=True))
