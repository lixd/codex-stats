#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/Codex Stats.app"
SOURCE=""
while (( $# )); do
  case "$1" in
    --destination|--source)
      if (( $# < 2 )); then echo "$1 需要 App 路径" >&2; exit 1; fi
      if [[ "$1" == --destination ]]; then APP="$2"; else SOURCE="$2"; fi
      shift 2 ;;
    *) echo "用法：$0 [--source BUILT_APP] [--destination TARGET_APP]" >&2; exit 1 ;;
  esac
done
# Preflight must not write into a destination that may be inside the source App.
HELPER_DIR="$(mktemp -d "/tmp/codexstats-install-helper.$$.XXXXXX")"
WORK=""
KEEP_WORK=0
cleanup() {
  if ! rm -rf "$HELPER_DIR"; then
    echo "检查工具临时目录清理失败：$HELPER_DIR" >&2
  fi
  if [[ -n "$WORK" && "$KEEP_WORK" == 0 ]]; then
    if ! rm -rf "$WORK"; then
      echo "暂存目录清理失败：$WORK；已经成功的发布不会因此撤销。" >&2
    fi
  elif [[ -n "$WORK" ]]; then
    echo "安装未完成或启动未确认，暂存目录保留供检查：$WORK" >&2
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun swiftc -swift-version 5 -framework AppKit "$ROOT/Scripts/app-delivery.swift" -o "$HELPER_DIR/app-delivery"
PLIST="$ROOT/Assets/Info.plist"
if [[ -n "$SOURCE" ]]; then PLIST="$SOURCE/Contents/Info.plist"; fi
"$HELPER_DIR/app-delivery" check "$PLIST" "$APP" install
mkdir -p "$(dirname "$APP")"
WORK="$(mktemp -d "$(dirname "$APP")/.codexstats-install.XXXXXX")"
if [[ -z "$SOURCE" ]]; then
  "$ROOT/Scripts/build-macos.sh" "$WORK/build"
  SOURCE="$WORK/build/Codex Stats.app"
fi
STAGED_APP="$WORK/Codex Stats.app"
ditto "$SOURCE" "$STAGED_APP"
KEEP_WORK=1
"$HELPER_DIR/app-delivery" publish "$STAGED_APP" "$APP" install
KEEP_WORK=0
echo "安装及启动核验完成。"
