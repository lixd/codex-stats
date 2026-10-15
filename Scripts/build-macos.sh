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
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/Assets/Info.plist" "$APP/Contents/Info.plist"

SDK="$(xcrun --sdk macosx --show-sdk-path)"
echo "正在构建 Codex Stats (${ARCH}, macOS 14+)…"
xcrun swiftc \
  -O -swift-version 5 -parse-as-library \
  -target "${ARCH}-apple-macosx14.0" \
  -sdk "$SDK" \
  -framework AppKit -framework SwiftUI -framework Charts \
  "$ROOT"/Sources/Core/*.swift "$ROOT"/Sources/App/*.swift \
  -o "$APP/Contents/MacOS/CodexStats"

# App icon is optional for running the app. Conversion uses stock macOS tools only.
if command -v sips >/dev/null && command -v iconutil >/dev/null; then
  ICONSET="$OUT/CodexStats.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  for SIZE in 16 32 128 256 512; do
    sips -s format png -z "$SIZE" "$SIZE" "$ROOT/Assets/CodexStats-1024.png" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -s format png -z "$DOUBLE" "$DOUBLE" "$ROOT/Assets/CodexStats-1024.png" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
  done
  # iconutil does not require a 64 or 1024 base (the 2x variants cover those).
  iconutil --convert icns "$ICONSET" --output "$APP/Contents/Resources/CodexStats.icns"
  rm -rf "$ICONSET"
fi

codesign --force --sign - --timestamp=none "$APP"
echo "构建成功：$APP"
echo "直接运行：open \"$APP\""
echo "安装到当前用户应用目录：mkdir -p \"$HOME/Applications\"; ditto \"$APP\" \"$HOME/Applications/Codex Stats.app\""
