#!/bin/zsh
# Builds SortLab.app next to this script. Usage: ./build.sh [run]
set -e
cd "$(dirname "$0")"
swift build -c release
APP=SortLab.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp algorithms.js "$APP/Contents/Resources/algorithms.js"
cp .build/release/SortLab "$APP/Contents/MacOS/SortLab"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>SortLab</string>
  <key>CFBundleIdentifier</key><string>local.sortlab</string>
  <key>CFBundleName</key><string>SortLab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Built $(pwd)/$APP"
[[ "$1" == "run" ]] && open "$APP"
