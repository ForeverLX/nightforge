#!/bin/bash
# wallpaper-rotate.sh - DMS-style wallpaper rotation for NightForge
# Auto-switches wallpaper every 15 minutes via systemd timer
# Usage: ./wallpaper-rotate.sh

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
MATUGEN_SYNC="$HOME/.local/bin/matugen-sync.sh"

# === FUNCTIONS ===
get_random_wallpaper() {
    # Find all image files (jpg, png, webp)
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1
}

# === MAIN ===
# Ensure wallpaper directory exists
if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "[-] Wallpaper directory not found: $WALLPAPER_DIR"
    exit 1
fi

# Get next wallpaper (avoid repeating current)
CURRENT=""
if [[ -f "$CACHE_FILE" ]]; then
    CURRENT=$(cat "$CACHE_FILE")
fi

# Select new wallpaper
NEW_WALLPAPER=$(get_random_wallpaper)

# Avoid repeating same wallpaper
while [[ "$NEW_WALLPAPER" == "$CURRENT" ]]; do
    NEW_WALLPAPER=$(get_random_wallpaper)
done

# Update cache
echo "$NEW_WALLPAPER" > "$CACHE_FILE"

# Set wallpaper with awww if available
if command -v awww &>/dev/null; then
    awww img "$NEW_WALLPAPER" --transition-type wipe --transition-duration 1
elif command -v swww &>/dev/null; then
    swww img "$NEW_WALLPAPER" --transition-type wipe --transition-duration 1
fi

# Always run matugen v4 pipeline
if [[ -x "$MATUGEN_SYNC" ]]; then
    bash "$MATUGEN_SYNC" "$NEW_WALLPAPER"
else
    echo "[-] matugen-sync.sh not found or not executable: $MATUGEN_SYNC"
    exit 1
fi

echo "[+] Wallpaper changed to: $(basename "$NEW_WALLPAPER")"
