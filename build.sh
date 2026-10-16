#!/bin/bash
# สร้าง ThaiFix.app จาก main.swift  (ต้องมี Xcode Command Line Tools: xcode-select --install)
set -e
cd "$(dirname "$0")"
APP=ThaiFix.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O main.swift -o "$APP/Contents/MacOS/ThaiFix" -framework Cocoa -framework Carbon
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>ThaiFix</string>
  <key>CFBundleIdentifier</key><string>com.thaifix.app</string>
  <key>CFBundleExecutable</key><string>ThaiFix</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "เสร็จแล้ว → เปิดด้วย: open $APP"
