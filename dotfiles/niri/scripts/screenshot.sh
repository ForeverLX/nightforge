#!/bin/bash
# Niri screenshot script with grim + slurp
# Supports area, window, screen, with/without annotations

MODE="${1:-area}"
SAVE_DIR="$HOME/Pictures/Screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SAVE_DIR"

case "$MODE" in
    area)
        # Select area with slurp, screenshot with grim
        grim -g "$(slurp)" "$SAVE_DIR/screenshot_${TIMESTAMP}.png"
        ;;
    
    area-clipboard)
        # Area to clipboard
        grim -g "$(slurp)" - | wl-copy
        notify-send "Screenshot" "Area copied to clipboard"
        ;;
    
    area-edit)
        # Area with annotation editor
        grim -g "$(slurp)" - | swappy -f -
        ;;
    
    screen)
        # Full screen (all monitors)
        grim "$SAVE_DIR/screenshot_${TIMESTAMP}.png"
        ;;
    
    screen-clipboard)
        # Full screen to clipboard
        grim - | wl-copy
        notify-send "Screenshot" "Screen copied to clipboard"
        ;;
    
    window)
        # Window screenshot (via niri)
        niri msg action screenshot-window
        ;;
    
    *)
        echo "Usage: $0 {area|area-clipboard|area-edit|screen|screen-clipboard|window}"
        exit 1
        ;;
esac
