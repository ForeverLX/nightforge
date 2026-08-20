#!/usr/bin/env bash
# Quickshell init — set wallpaper + matugen theme sync

FLAG="$HOME/.cache/wallpaper_initialized"
MATUGEN_SYNC="$HOME/.local/bin/matugen-sync.sh"

# If already initialized, just re-sync with current wallpaper
if [ -f "$FLAG" ]; then
    if [ -f "/tmp/qs_current_wallpaper" ]; then
        WALL=$(cat /tmp/qs_current_wallpaper)
        if [ -f "$WALL" ]; then
            "$MATUGEN_SYNC" "$WALL" &>/dev/null &
        fi
    fi
    exit 0
fi

# Find wallpaper directory
WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
if [ ! -d "$WALLPAPER_DIR" ]; then
    WALLPAPER_DIR=$(find "$HOME/Pictures" -maxdepth 2 -type d -iname "wallpaper*" 2>/dev/null | head -1)
fi

if [ -n "$WALLPAPER_DIR" ] && [ -d "$WALLPAPER_DIR" ]; then
    file=$(find "$WALLPAPER_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) 2>/dev/null | shuf -n 1)

    if [ -n "$file" ]; then
        cp "$file" /tmp/lock_bg.png
        echo "$file" > /tmp/qs_current_wallpaper

        awww img "$file" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1 &>/dev/null &

        "$MATUGEN_SYNC" "$file" &>/dev/null &
    fi
fi

mkdir -p "$(dirname "$FLAG")"
touch "$FLAG"
