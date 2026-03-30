#!/bin/bash
# screenshot.sh — Multi-mode screenshot system
# Modes: area-pip, area-clipboard, area-edit, screen, screen-clipboard
# Dependencies: grim, slurp, satty, wl-copy, fuzzel, notify-send

set -euo pipefail

MODE="${1:-area-pip}"
SAVE_DIR="$HOME/Pictures/Screenshots"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$SAVE_DIR"

# Build filename prefix — tmux context if inside tmux, else timestamp
if [[ -n "${TMUX:-}" ]]; then
    TMUX_CONTEXT=$(tmux display -p '#S-#I' 2>/dev/null || echo "tmux")
    DEFAULT_NAME="${TMUX_CONTEXT}_${TIMESTAMP}"
else
    DEFAULT_NAME="screenshot_${TIMESTAMP}"
fi

# Fuzzel filename prompt for save modes
prompt_filename() {
    local result
    result=$(echo "$DEFAULT_NAME" | fuzzel --dmenu \
        --prompt="filename: " \
        --lines=0 \
        --width=40) || true
    echo "${result:-$DEFAULT_NAME}"
}

case "$MODE" in
    area-pip)
        FILENAME=$(prompt_filename)
        OUTPUT="$SAVE_DIR/${FILENAME}.png"
        grim -g "$(slurp)" - | satty \
            --filename - \
            --output-filename "$OUTPUT" \
            --copy-command wl-copy \
            --initial-tool arrow \
            --actions-on-enter "save-to-file,save-to-clipboard,exit" \
            --actions-on-escape exit \
            --early-exit \
            --floating-hack \
            --no-window-decoration
        [[ -f "$OUTPUT" ]] && notify-send "Screenshot Saved" "${FILENAME}.png"
        ;;

    area-clipboard)
        grim -g "$(slurp)" - | satty \
            --filename - \
            --copy-command wl-copy \
            --initial-tool arrow \
            --actions-on-enter "save-to-clipboard,exit" \
            --actions-on-escape exit \
            --early-exit \
            --floating-hack \
            --no-window-decoration
        notify-send "Screenshot Copied" "Area copied to clipboard"
        ;;

    area-edit)
        FILENAME=$(prompt_filename)
        OUTPUT="$SAVE_DIR/${FILENAME}.png"
        grim -g "$(slurp)" - | satty \
            --filename - \
            --output-filename "$OUTPUT" \
            --copy-command wl-copy \
            --initial-tool brush \
            --actions-on-enter "save-to-file,save-to-clipboard,exit" \
            --actions-on-escape exit \
            --early-exit \
            --floating-hack \
            --no-window-decoration
        [[ -f "$OUTPUT" ]] && notify-send "Screenshot Saved" "${FILENAME}.png"
        ;;

    screen)
        FILENAME=$(prompt_filename)
        OUTPUT="$SAVE_DIR/${FILENAME}.png"
        grim - | satty \
            --filename - \
            --output-filename "$OUTPUT" \
            --copy-command wl-copy \
            --initial-tool arrow \
            --actions-on-enter "save-to-file,save-to-clipboard,exit" \
            --actions-on-escape exit \
            --early-exit \
            --floating-hack \
            --no-window-decoration
        [[ -f "$OUTPUT" ]] && notify-send "Screenshot Saved" "${FILENAME}.png"
        ;;

    screen-clipboard)
        grim - | wl-copy
        notify-send "Screenshot Copied" "Full screen copied to clipboard"
        ;;

    *)
        echo "Unknown mode: $MODE" >&2
        echo "Usage: $0 [area-pip|area-clipboard|area-edit|screen|screen-clipboard]" >&2
        exit 1
        ;;
esac
