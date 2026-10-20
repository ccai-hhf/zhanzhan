#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
trap 'status=$?; if [ "$status" -ne 0 ] && [ -t 0 ]; then read -r -p "安装未完成，请查看上面的错误。按回车关闭…"; fi' EXIT
bash scripts/build-app.sh release
bash scripts/install-app.sh
