#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh release
app="$PWD/dist/沾沾.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
arch=$(uname -m)
asset="ZhanZhan-${version}-macOS-${arch}.zip"
staging=$(mktemp -d "${TMPDIR:-/tmp}/zhanzhan-package.XXXXXX")
trap 'rm -rf "$staging"' EXIT
ditto --norsrc --noextattr "$app" "$staging/沾沾.app"
cp docs/INSTALL.md "$staging/安装说明.md"
cp LICENSE "$staging/LICENSE"
codesign --verify --deep --strict "$staging/沾沾.app"
ditto -c -k --norsrc --noextattr "$staging" "dist/$asset"
(cd dist && shasum -a 256 "$asset" > "$asset.sha256")
echo "Release: dist/$asset"
