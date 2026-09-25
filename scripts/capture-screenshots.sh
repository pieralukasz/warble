#!/bin/bash
# Renders every Warble screen on sample data and saves a PNG per screen.
# Needs Screen Recording permission for the terminal running it.
set -euo pipefail

APP="${APP:-.build/Warble.app}"
OUT_DIR="${1:-docs-site/public/screenshots}"
SCENES=(menubar history dictionary settings onboarding-0 onboarding-1 onboarding-3 onboarding-4 onboarding-5 pill-recording pill-transcribing pill-inserted)
SETTLE_SECONDS="${SETTLE_SECONDS:-2.5}"

mkdir -p "$OUT_DIR"
LOG="$(mktemp -t warble-preview)"
trap 'rm -f "$LOG"' EXIT

for scene in "${SCENES[@]}"; do
    : > "$LOG"
    WARBLE_PREVIEW="$scene" "$APP/Contents/MacOS/warble" start > "$LOG" 2>&1 &
    pid=$!
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

    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
done
