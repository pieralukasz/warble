#!/bin/bash
# Removes Warble. Settings, history, dictionary and the downloaded model are
# kept unless you pass --purge.
set -euo pipefail

PURGE=false
[ "${1:-}" = "--purge" ] && PURGE=true

osascript -e 'tell application "Warble" to quit' 2>/dev/null || true
sleep 1

rm -rf "$HOME/Applications/Warble.app"
rm -f "$HOME/.local/bin/warble"
rm -f "$HOME/Library/LaunchAgents/io.github.pieralukasz.warble.plist"
echo "Removed Warble.app, the warble command and the login item."

if $PURGE; then
    rm -rf "$HOME/.config/warble"
    rm -rf "$HOME/Library/Application Support/Warble"
    echo "Removed settings, recordings, history and dictionary."
    echo "The Parakeet model in ~/Library/Application Support/FluidAudio is shared with other FluidAudio apps and was left in place."
else
    echo "Kept ~/.config/warble and ~/Library/Application Support/Warble. Run with --purge to delete them."
fi
