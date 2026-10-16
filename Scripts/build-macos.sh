#!/usr/bin/env bash
# Build a self-contained, ad-hoc signed macOS application. Requires macOS + Xcode/CLT.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
APP="$OUT/Codex Stats.app"
ARCH="$(uname -m)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "此脚本只能在 macOS 上执行。当前平台: $(uname -s)" >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "缺少 Apple Swift 编译环境。请先运行 xcode-select --install，或安装 Xcode。" >&2
  exit 1
fi

mkdir -p "$OUT"
WORK="$(mktemp -d "$OUT/.codexstats-build.XXXXXX")"
KEEP_WORK=0
cleanup() {
  if [[ "$KEEP_WORK" == 0 ]]; then
    if ! rm -rf "$WORK"; then
      echo "暂存目录清理失败：$WORK；已经成功的发布不会因此撤销。" >&2
    fi
  else
    echo "发布未完成或未确认，暂存目录保留供检查：$WORK" >&2
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
xcrun swiftc -swift-version 5 -framework AppKit "$ROOT/Scripts/app-delivery.swift" -o "$WORK/app-delivery"
"$WORK/app-delivery" check "$ROOT/Assets/Info.plist" "$APP" build
STAGED_APP="$WORK/Codex Stats.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$ROOT/Assets/Info.plist" "$STAGED_APP/Contents/Info.plist"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "正在构建 Codex Stats (${ARCH}, macOS 14+)…"
xcrun swiftc \
  -O -swift-version 5 -parse-as-library \
  -target "${ARCH}-apple-macosx14.0" \
  -sdk "$SDK" \
  -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "$ROOT"/Sources/App/*.swift \
  -o "$STAGED_APP/Contents/MacOS/CodexStats"

# App icon is optional for running the app. Conversion uses stock macOS tools only.
if command -v sips >/dev/null && command -v iconutil >/dev/null; then
  ICONSET="$WORK/CodexStats.iconset"
  mkdir -p "$ICONSET"
  for SIZE in 16 32 128 256 512; do
    sips -s format png -z "$SIZE" "$SIZE" "$ROOT/Assets/CodexStats-1024.png" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -s format png -z "$DOUBLE" "$DOUBLE" "$ROOT/Assets/CodexStats-1024.png" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  done
  # iconutil does not require a 64 or 1024 base (the 2x variants cover those).
  iconutil --convert icns "$ICONSET" --output "$STAGED_APP/Contents/Resources/CodexStats.icns"
  rm -rf "$ICONSET"
fi

codesign --force --sign - --timestamp=none "$STAGED_APP"
# Once publication begins, a failed launch/interrupt may leave the old App here.
# Never remove that recovery copy on a failure.
KEEP_WORK=1
"$WORK/app-delivery" publish "$STAGED_APP" "$APP" build
KEEP_WORK=0
echo "构建成功：$APP"
echo "直接运行：open \"$APP\""
echo "安全安装：./Scripts/install-local.sh --source \"$APP\""
