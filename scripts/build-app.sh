#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Applications/VPSMonitor.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICONSET="$ROOT/.build/VPSMonitor.iconset"
ICON_FILE="$RESOURCES/VPSMonitor.icns"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/KomariMonitor" "$MACOS/VPSMonitor"
cp "Sources/KomariMonitor/KomariLogo.png" "$RESOURCES/KomariLogo.png"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "Sources/KomariMonitor/KomariLogo.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICON_FILE"
rm -rf "$ICONSET"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>VPSMonitor</string>
  <key>CFBundleIdentifier</key>
  <string>local.komari.monitor</string>
  <key>CFBundleName</key>
  <string>VPSMonitor</string>
  <key>CFBundleDisplayName</key>
  <string>VPSMonitor</string>
  <key>CFBundleIconFile</key>
  <string>VPSMonitor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
