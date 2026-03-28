#!/bin/bash
# Rename the most recent screenshot

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"

# Find most recent screenshot
LAST_SCREENSHOT=$(ls -t "$SCREENSHOT_DIR"/screenshot_*.png 2>/dev/null | head -1)

if [[ -z "$LAST_SCREENSHOT" ]]; then
    notify-send "No Screenshot" "No recent screenshots found"
    exit 1
fi

# Prompt for new name
if command -v zenity &>/dev/null; then
    NEW_NAME=$(zenity --entry \
        --title="Rename Screenshot" \
        --text="Current: $(basename "$LAST_SCREENSHOT")\nNew name:" \
        --entry-text="")
    
    if [[ -n "$NEW_NAME" ]]; then
        # Ensure .png extension
        [[ "$NEW_NAME" != *.png ]] && NEW_NAME="${NEW_NAME}.png"
        
        NEW_PATH="$SCREENSHOT_DIR/$NEW_NAME"
        mv "$LAST_SCREENSHOT" "$NEW_PATH"
        notify-send "Screenshot Renamed" "$NEW_NAME"
    fi
fi
