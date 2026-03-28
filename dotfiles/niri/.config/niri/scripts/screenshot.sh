#!/bin/bash
# Multi-mode screenshot system with filename prompt

MODE="${1:-area-pip}"
SAVE_DIR="$HOME/Pictures/Screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Prompt for custom filename (optional)
if command -v zenity &>/dev/null && [[ "$MODE" != *"clipboard"* ]]; then
    CUSTOM_NAME=$(zenity --entry \
        --title="Screenshot Filename" \
        --text="Enter filename (or leave blank for timestamp):" \
        --entry-text="screenshot_${TIMESTAMP}")
    
    if [[ -n "$CUSTOM_NAME" ]]; then
        FILENAME="$CUSTOM_NAME"
    else
        FILENAME="screenshot_${TIMESTAMP}"
    fi
else
    FILENAME="screenshot_${TIMESTAMP}"
fi

TEMP_FILE="/tmp/${FILENAME}.png"
FINAL_FILE="$SAVE_DIR/${FILENAME}.png"

mkdir -p "$SAVE_DIR"

case "$MODE" in
    area-pip)
        grim -g "$(slurp)" "$TEMP_FILE"
        if [[ -f "$TEMP_FILE" ]]; then
            swappy -f "$TEMP_FILE" -o "$FINAL_FILE"
            if [[ -f "$FINAL_FILE" ]]; then
                notify-send "Screenshot Saved" "$FILENAME.png"
            fi
            rm -f "$TEMP_FILE"
        fi
        ;;
    
    # ... rest of modes unchanged
esac
