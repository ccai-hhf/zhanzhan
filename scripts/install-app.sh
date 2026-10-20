#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="$PWD/dist/沾沾.app"
if [ ! -d "$app" ]; then echo '请先运行 bash scripts/build-app.sh release'; exit 1; fi
if pgrep -x ZhanZhan >/dev/null; then
  echo '请先从沾沾的更多菜单选择“退出沾沾”，再运行 bash scripts/install-app.sh。' >&2
  exit 1
fi
if [ -n "${INSTALL_DIR:-}" ]; then
  destination="$INSTALL_DIR"
elif [ -w /Applications ]; then
  destination=/Applications
else
  destination="$HOME/Applications"
fi
mkdir -p "$destination"
codesign --verify --deep --strict "$app"
if [ -e "$destination/沾沾.app" ]; then
  backup_dir="$HOME/Library/Application Support/ZhanZhan/AppBackups/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$backup_dir"
  mv "$destination/沾沾.app" "$backup_dir/沾沾.app"
  echo "旧应用已备份到 $backup_dir（剪贴板数据不变）"
fi
ditto "$app" "$destination/沾沾.app"
codesign --verify --deep --strict "$destination/沾沾.app"
echo "已安装到 $destination/沾沾.app"
open "$destination/沾沾.app"
