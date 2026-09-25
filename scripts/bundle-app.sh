#!/bin/bash
set -euo pipefail

BINARY="${1:-.build/release/warble}"
APP_DIR="${2:-Warble.app}"
VERSION="${3:-0.1.0}"
BUNDLE_ID="io.github.pieralukasz.warble"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/warble"

find .build -maxdepth 6 -type d -name 'FluidAudio_FluidAudio.bundle' -exec \
    ditto {} "$APP_DIR/Contents/Resources/FluidAudio_FluidAudio.bundle" \; -quit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Compiles the layered Liquid Glass icon into Assets.car plus a Warble.icns fallback.
# actool only accepts absolute paths.
RESOURCES_DIR="$(cd "$APP_DIR/Contents/Resources" && pwd)"
xcrun actool "$REPO_DIR/Resources/Warble.icon" \
    --compile "$RESOURCES_DIR" \
    --output-partial-info-plist "$(mktemp -t warble-icon).plist" \
    --app-icon Warble --include-all-app-icons \
    --enable-on-demand-resources NO --development-region en \
    --target-device mac --minimum-deployment-target 26.0 --platform macosx \
    --errors --warnings > /dev/null

cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>warble</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>Warble</string>
    <key>CFBundleDisplayName</key>
    <string>Warble</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>CFBundleIconFile</key>
    <string>Warble</string>
    <key>CFBundleIconName</key>
    <string>Warble</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Warble listens only while you hold the dictation key, and transcribes on this Mac.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Warble needs system audio access to transcribe audio playing on this Mac.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_DIR"

echo "Built $APP_DIR"
