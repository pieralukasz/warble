#!/bin/bash
# Builds Warble from source and installs it for the current user:
#   ~/Applications/Warble.app and the `warble` command in ~/.local/bin.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/.*version = "\(.*\)".*/\1/p' Sources/WarbleKit/Version.swift)"
APP_DIR="$HOME/Applications/Warble.app"
BIN_DIR="$HOME/.local/bin"

echo "Building Warble ${VERSION}…"
swift build --disable-sandbox -c release
scripts/bundle-app.sh .build/release/warble .build/Warble.app "$VERSION"

if pgrep -f "Warble.app/Contents/MacOS/warble" > /dev/null; then
    echo "Quitting the running copy…"
    osascript -e 'tell application "Warble" to quit' || true
    sleep 1
fi

mkdir -p "$HOME/Applications" "$BIN_DIR"
rm -rf "$APP_DIR"
ditto .build/Warble.app "$APP_DIR"
ln -sfn "$APP_DIR/Contents/MacOS/warble" "$BIN_DIR/warble"

echo "Installed $APP_DIR"
echo "Command line: $BIN_DIR/warble (make sure it is on your PATH)"
open "$APP_DIR"
