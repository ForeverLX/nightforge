#!/bin/bash
# rename-last-screenshot.sh — Rename a screenshot via fuzzel selection
# Dependencies: fuzzel, notify-send

set -euo pipefail

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

mapfile -t SCREENSHOTS < <(ls -t "$SCREENSHOT_DIR"/*.png 2>/dev/null)

if [[ ${#SCREENSHOTS[@]} -eq 0 ]]; then
    notify-send "No Screenshots" "No PNG files in $SCREENSHOT_DIR"
    exit 1
fi

SELECTED=$(printf '%s\n' "${SCREENSHOTS[@]}" | \
    xargs -I{} basename {} | \
    fuzzel --dmenu \
        --prompt="rename: " \
        --lines=10 \
        --width=50) || exit 0

SELECTED_PATH="$SCREENSHOT_DIR/$SELECTED"

if [[ ! -f "$SELECTED_PATH" ]]; then
    notify-send "Error" "File not found: $SELECTED"
    exit 1
fi

CURRENT_BASE="${SELECTED%.png}"
NEW_NAME=$(echo "$CURRENT_BASE" | fuzzel --dmenu \
    --prompt="new name: " \
    --lines=0 \
    --width=50) || exit 0

[[ -z "$NEW_NAME" ]] && exit 0
[[ "$NEW_NAME" != *.png ]] && NEW_NAME="${NEW_NAME}.png"

NEW_PATH="$SCREENSHOT_DIR/$NEW_NAME"

if [[ -f "$NEW_PATH" ]]; then
    notify-send "Error" "File already exists: $NEW_NAME"
    exit 1
fi

mv "$SELECTED_PATH" "$NEW_PATH"
notify-send "Screenshot Renamed" "$SELECTED → $NEW_NAME"
