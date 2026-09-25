#!/bin/bash
# Renders every Warble screen on sample data and saves a PNG per screen.
# Needs Screen Recording permission for the terminal running it.
set -euo pipefail

APP="${APP:-.build/Warble.app}"
OUT_DIR="${1:-docs-site/public/screenshots}"
SCENES=(menubar history dictionary settings onboarding-0 onboarding-1 onboarding-2 onboarding-3 onboarding-4 onboarding-5 pill-recording pill-transcribing pill-inserted)
SETTLE_SECONDS="${SETTLE_SECONDS:-2.5}"
BINARY="$(cd "$APP/Contents/MacOS" && pwd)/warble"

mkdir -p "$OUT_DIR"
LOG="$(mktemp -t warble-preview)"
trap 'rm -f "$LOG"; pkill -f "$BINARY" || true' EXIT

for scene in "${SCENES[@]}"; do
    : > "$LOG"
    # Launching through LaunchServices lets the window become key, so it is
    # captured with active traffic lights, selection and accent colors.
    open -n --env "WARBLE_PREVIEW=$scene" --stdout "$LOG" --stderr "$LOG" "$APP" --args start
    sleep 1
    # Opening the running copy again brings it to the front even when the
    # terminal is in the background.
    open "$APP"
    sleep "$SETTLE_SECONDS"

    window_id="$(sed -n 's/^Preview window \([0-9]*\)$/\1/p' "$LOG" | head -1)"
    if [ -z "$window_id" ]; then
        echo "  skip $scene: no window reported"
        cat "$LOG"
    elif screencapture -x -o -l "$window_id" "$OUT_DIR/$scene.png"; then
        echo "  saved $OUT_DIR/$scene.png"
    else
        echo "  fail $scene: screencapture could not read window $window_id"
    fi

    pkill -f "$BINARY" || true
    sleep 0.5
done
