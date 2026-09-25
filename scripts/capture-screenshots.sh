#!/bin/bash
# Renders every Warble screen on sample data and saves a PNG per screen.
# Needs Screen Recording permission for the terminal running it.
set -euo pipefail

APP="${APP:-.build/Warble.app}"
OUT_DIR="${1:-docs-site/public/screenshots}"
SCENES=(menubar menubar@dark history dictionary settings onboarding-0 onboarding-1 onboarding-2 onboarding-3 onboarding-4 onboarding-5 pill-recording pill-transcribing pill-inserted)
SETTLE_SECONDS="${SETTLE_SECONDS:-2.5}"
BINARY="$(cd "$APP/Contents/MacOS" && pwd)/warble"

mkdir -p "$OUT_DIR"

# The last activation line the app printed: "active" or "inactive".
activation_state() {
    sed -n -E 's/^Preview (active|inactive)$/\1/p' "$LOG" | tail -1
}
LOG="$(mktemp -t warble-preview)"
trap 'rm -f "$LOG"; pkill -f "$BINARY" || true' EXIT

for entry in "${SCENES[@]}"; do
    # "scene@dark" renders the scene in Dark Mode and saves it as scene-dark.png.
    scene="${entry%@*}"
    appearance="light"
    name="$scene"
    if [[ "$entry" == *@* ]]; then
        appearance="${entry#*@}"
        name="$scene-$appearance"
    fi
    : > "$LOG"
    # Launching through LaunchServices lets the window become key, so it is
    # captured with active traffic lights, selection and accent colors.
    open -n --env "WARBLE_PREVIEW=$scene" --env "WARBLE_APPEARANCE=$appearance" --stdout "$LOG" --stderr "$LOG" "$APP" --args start
    sleep 1
    # Opening the running copy again brings it to the front even when the
    # terminal is in the background.
    open "$APP"
    sleep "$SETTLE_SECONDS"
    # macOS may refuse to switch apps while you are typing elsewhere; keep
    # asking until Warble reports that it is the active app.
    for _ in 1 2 3 4 5 6 7 8; do
        [ "$(activation_state)" = "active" ] && break
        open "$APP"
        sleep 1
    done
    [ "$(activation_state)" = "active" ] || echo "  warn $name: captured while inactive"

    window_id="$(sed -n 's/^Preview window \([0-9]*\)$/\1/p' "$LOG" | head -1)"
    if [ -z "$window_id" ]; then
        echo "  skip $name: no window reported"
        cat "$LOG"
    elif screencapture -x -o -l "$window_id" "$OUT_DIR/$name.png"; then
        echo "  saved $OUT_DIR/$name.png"
    else
        echo "  fail $name: screencapture could not read window $window_id"
    fi

    pkill -f "$BINARY" || true
    sleep 0.5
done
