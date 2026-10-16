#!/usr/bin/env bash
# Render the real SwiftUI views with synthetic local logs; no screen capture or clicks.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist/ui-previews}"
PALETTE="${2:-cyan}"
case "$PALETTE" in cyan|blue) ;; *) echo "配色必须为 cyan 或 blue" >&2; exit 2 ;; esac
WORK="$(mktemp -d "${TMPDIR:-/tmp}/codexstats-preview.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/sessions" "$OUT"
DAY="$(date +%Y-%m-%d)"
OFFSET="$(date +%z)"
ZONE="${OFFSET:0:3}:${OFFSET:3:2}"
cat > "$WORK/sessions/synthetic.jsonl" <<EOF
{"type":"session_meta","timestamp":"${DAY}T08:00:00${ZONE}","payload":{"id":"preview-session","cwd":"/example/project"}}
{"type":"turn_context","timestamp":"${DAY}T08:00:01${ZONE}","payload":{"model":"example-model-A","turn_id":"preview-turn-A"}}
{"type":"event_msg","timestamp":"${DAY}T08:30:00${ZONE}","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":40000000,"cached_input_tokens":36000000,"output_tokens":400000,"reasoning_output_tokens":200000}}}}
{"type":"token_usage_record","timestamp":"${DAY}T09:29:59${ZONE}","payload":{"thread_id":"preview-session","turn_id":"preview-turn-A","response_id":"preview-response-2","usage":{"input_tokens":120000000,"cached_input_tokens":112000000,"output_tokens":1200000,"reasoning_output_tokens":600000},"thread_token_usage":{"input_tokens":160000000,"cached_input_tokens":148000000,"output_tokens":1600000,"reasoning_output_tokens":800000}}}
{"type":"event_msg","timestamp":"${DAY}T09:30:00${ZONE}","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":160000000,"cached_input_tokens":148000000,"output_tokens":1600000,"reasoning_output_tokens":800000}}}}
{"type":"turn_context","timestamp":"${DAY}T10:00:00${ZONE}","payload":{"model":"example-model-B-with-a-long-descriptive-name","turn_id":"preview-turn-B"}}
{"type":"event_msg","timestamp":"${DAY}T10:30:00${ZONE}","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":340000000,"cached_input_tokens":320000000,"output_tokens":3400000,"reasoning_output_tokens":1600000},"last_token_usage":{"input_tokens":180000000,"cached_input_tokens":172000000,"output_tokens":1800000,"reasoning_output_tokens":800000}}}}
EOF
for AGO in 1 2 3 4 5 6; do
  PREVIOUS_DAY="$(date -v-"${AGO}"d +%Y-%m-%d)"
  INPUT=$(((7 - AGO) * 60000000))
  CACHED=$((INPUT * 9 / 10))
  cat > "$WORK/sessions/synthetic-${AGO}.jsonl" <<EOF
{"type":"session_meta","timestamp":"${PREVIOUS_DAY}T08:00:00${ZONE}","payload":{"id":"preview-session-${AGO}","cwd":"/example/project"}}
{"type":"turn_context","timestamp":"${PREVIOUS_DAY}T08:00:01${ZONE}","payload":{"model":"example-model-A"}}
{"type":"event_msg","timestamp":"${PREVIOUS_DAY}T10:30:00${ZONE}","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":${INPUT},"cached_input_tokens":${CACHED},"output_tokens":500000,"reasoning_output_tokens":200000}}}}
EOF
done
# A genuine complete multi-response Turn, plus an unknown-timing response.
cat > "$WORK/sessions/timed.jsonl" <<EOF
{"type":"session_meta","timestamp":"${DAY}T13:00:00${ZONE}","payload":{"id":"preview-timed","cwd":"/example/timed-project"}}
{"type":"turn_context","timestamp":"${DAY}T13:00:00${ZONE}","payload":{"model":"example-model-A","turn_id":"timed-turn"}}
{"type":"event_msg","timestamp":"${DAY}T13:00:00${ZONE}","payload":{"type":"task_started","turn_id":"timed-turn"}}
{"type":"response_item","timestamp":"${DAY}T13:00:20${ZONE}","payload":{"type":"message","role":"assistant","content":[]}}
{"type":"token_usage_record","timestamp":"${DAY}T13:00:30${ZONE}","payload":{"thread_id":"preview-timed","turn_id":"timed-turn","response_id":"timed-first","usage":{"input_tokens":1000000,"cached_input_tokens":800000,"output_tokens":1200,"reasoning_output_tokens":600}}}
{"type":"response_item","timestamp":"${DAY}T13:00:45${ZONE}","payload":{"type":"function_call_output","call_id":"preview-tool","output":"synthetic"}}
{"type":"response_item","timestamp":"${DAY}T13:01:10${ZONE}","payload":{"type":"reasoning","summary":[]}}
{"type":"token_usage_record","timestamp":"${DAY}T13:01:30${ZONE}","payload":{"thread_id":"preview-timed","turn_id":"timed-turn","response_id":"timed-last","usage":{"input_tokens":2000000,"cached_input_tokens":1800000,"output_tokens":2400,"reasoning_output_tokens":1200}}}
{"type":"event_msg","timestamp":"${DAY}T13:02:00${ZONE}","payload":{"type":"task_complete","turn_id":"timed-turn","duration_ms":120000,"time_to_first_token_ms":2000}}
{"type":"token_usage_record","timestamp":"${DAY}T14:00:00${ZONE}","payload":{"thread_id":"preview-timed","turn_id":"unknown-turn","response_id":"unknown-timing","usage":{"input_tokens":500000,"output_tokens":1000}}}
EOF
mkdir -p "$WORK/archived_sessions" "$WORK/empty/sessions"
cp "$WORK/sessions/timed.jsonl" "$WORK/archived_sessions/timed-copy.jsonl"
printf '%s\n' 'damaged synthetic row' > "$WORK/sessions/damaged.jsonl"
APP_SOURCES=()
for SOURCE in "$ROOT"/Sources/App/*.swift; do
  if [[ "$SOURCE" != "$ROOT/Sources/App/CodexStatsApp.swift" ]]; then APP_SOURCES+=("$SOURCE"); fi
done
xcrun swiftc -swift-version 5 -parse-as-library -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "${APP_SOURCES[@]}" "$ROOT/Tests/UIPreview/main.swift" -o "$WORK/preview"
CODEX_HOME="$WORK" CODEX_STATS_PREVIEW_PALETTE="$PALETTE" "$WORK/preview" "$OUT"
