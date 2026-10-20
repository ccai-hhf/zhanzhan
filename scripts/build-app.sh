#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/doctor.sh
configuration="${1:-release}"
swift build -c "$configuration" --force-resolved-versions -j 4
bin_dir="$(swift build -c "$configuration" --show-bin-path)"
app_dir="$PWD/dist/沾沾.app"
if [ -d "$app_dir" ]; then rm -rf "$app_dir"; fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/ZhanZhan" "$app_dir/Contents/MacOS/ZhanZhan"
for bundle in "$bin_dir"/*.bundle; do
  [ -d "$bundle" ] || continue
  ditto "$bundle" "$app_dir/Contents/Resources/$(basename "$bundle")"
done
for locale in Maccy/*.lproj; do
  ditto "$locale" "$app_dir/Contents/Resources/$(basename "$locale")"
done
cp Maccy/Sounds/*.caf "$app_dir/Contents/Resources/"
cp NativeTouch/LICENSE "$app_dir/Contents/Resources/OpenMultitouchSupport-LICENSE.txt"
cp LICENSE "$app_dir/Contents/Resources/Maccy-LICENSE.txt"
cp Vendor/KeyboardShortcuts/license "$app_dir/Contents/Resources/KeyboardShortcuts-LICENSE.txt"
# Ship dependency notices with the standalone application.
mkdir -p "$app_dir/Contents/Resources/ThirdPartyLicenses"
python3 - "$app_dir" <<'PY'
import pathlib, plistlib, sys
app = pathlib.Path(sys.argv[1])
licenses = app / 'Contents/Resources/ThirdPartyLicenses'
for dependency in pathlib.Path('.build/checkouts').iterdir():
  for notice in dependency.iterdir():
    if notice.is_file() and notice.name.lower().split('.')[0] in ('license', 'licence', 'copying', 'notice'):
      (licenses / f'{dependency.name}-{notice.name}').write_bytes(notice.read_bytes())
info = {
  'CFBundleName': '沾沾', 'CFBundleDisplayName': '沾沾',
  'CFBundleExecutable': 'ZhanZhan', 'CFBundleIdentifier': 'local.zhanzhan.clipboard',
  'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': '0.3.1', 'CFBundleVersion': '4',
  'CFBundleDevelopmentRegion': 'zh-Hans', 'CFBundleIconFile': 'ZhanZhan',
  'LSMinimumSystemVersion': '14.0', 'LSUIElement': True,
  'NSPrincipalClass': 'NSApplication',
  'NSHumanReadableCopyright': 'Based on Maccy © Alex Rodionov. MIT License.',
  'LSApplicationCategoryType': 'public.app-category.productivity'
}
with (app / 'Contents/Info.plist').open('wb') as f: plistlib.dump(info, f)
PY
swift scripts/make-icon.swift "$PWD/dist/ZhanZhan.iconset"
iconutil -c icns dist/ZhanZhan.iconset -o "$app_dir/Contents/Resources/ZhanZhan.icns"
codesign --force --deep --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
printf 'Built %s\n' "$app_dir"
