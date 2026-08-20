#!/bin/bash
# Rotate wallpaper + trigger matugen color sync

set -e

export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export DISPLAY="${DISPLAY:-:0}"

QS_SCRIPTS="$HOME/.config/quickshell/scripts"
WALLPAPER_DIRS=("$HOME/Pictures/Wallpapers" "$HOME/Pictures/wallpapers")

# Find wallpaper directories
for d in "${WALLPAPER_DIRS[@]}"; do
    [ -d "$d" ] && WALL_DIR="$d" && break
done

# Cached wallpapers (fallback if no dedicated wallpaper dir)
if [ -z "$WALL_DIR" ]; then
    WALL_DIR=$(find "$HOME" -maxdepth 3 -type d -name "Wallpapers" -o -name "wallpapers" -o -name "Backgrounds" 2>/dev/null | head -1)
fi

if [ -z "$WALL_DIR" ] || [ ! -d "$WALL_DIR" ]; then
    mkdir -p "$HOME/Pictures/Wallpapers"
    exit 0
fi

# Pick a random wallpaper
# -L: follow symlinks — WALL_DIR may be Wallpapers->wallpapers symlink; without
#     it find returns nothing and we silently exit 0 (CR1MS0NOPS-3).
CURRENT=$(cat /tmp/qs_current_wallpaper 2>/dev/null || echo "")
WALL=$(find -L "$WALL_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null | grep -v "$CURRENT" | shuf -n 1)

[ -z "$WALL" ] && WALL=$(find -L "$WALL_DIR" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) 2>/dev/null | shuf -n 1)
[ -z "$WALL" ] && echo "[-] rotate-wallpaper.sh: no wallpapers found under $WALL_DIR" >&2 && exit 1

# Set wallpaper
awww img "$WALL" --transition-type any --transition-pos 0.5,0.5 --transition-fps 144 --transition-duration 1

echo "$WALL" > /tmp/qs_current_wallpaper

# Trigger matugen
"$HOME/.local/bin/matugen-sync.sh" "$WALL"
