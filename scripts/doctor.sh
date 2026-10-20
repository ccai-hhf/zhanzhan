#!/bin/bash
set -euo pipefail
if [ "$(uname -s)" != Darwin ]; then
  echo '沾沾是原生 macOS 应用，构建与运行均需要 Mac。' >&2
  exit 1
fi
for tool in swift xcrun python3 codesign iconutil ditto; do
  if ! command -v "$tool" >/dev/null; then
    echo "缺少 $tool。请安装 Xcode 26.5+ 或配套 Command Line Tools。" >&2
    exit 1
  fi
done
python3 - <<'PY'
import re, subprocess, sys
version = subprocess.check_output(['swift', '--version'], text=True)
match = re.search(r'Swift version (\d+)\.(\d+)', version)
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-version'], text=True).strip()
if not match or tuple(map(int, match.groups())) < (6, 3) or int(sdk.split('.')[0]) < 26:
    sys.exit('需要 Swift 6.3+ 和 macOS 26 SDK。请安装 Xcode 26.5+ 或对应 CLT，并用 xcode-select 选择它。')
print(version.strip())
print('macOS SDK:', sdk)
PY
