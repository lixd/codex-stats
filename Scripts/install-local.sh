#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build-macos.sh" "$ROOT/dist"
mkdir -p "$HOME/Applications"
APP="$HOME/Applications/Codex Stats.app"
if [[ -d "$APP" ]]; then
  echo "正在替换当前用户的旧版本：$APP"
  rm -rf "$APP"
fi
ditto "$ROOT/dist/Codex Stats.app" "$APP"
open "$APP"
echo "安装完成。顶部菜单栏会出现 Codex Stats 图标。"
