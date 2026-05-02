#!/bin/bash
# wallpaper-rotate.sh - DMS-style wallpaper rotation for NightForge
# Auto-switches wallpaper every 15 minutes via systemd timer
# Usage: ./wallpaper-rotate.sh [--notify]

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CACHE_FILE="$HOME/.cache/current_wallpaper"
MRU_FILE="$HOME/.cache/wallpaper-mru"
MATUGEN_SYNC="$HOME/.local/bin/matugen-sync.sh"
NOTIFY=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --notify)
            NOTIFY=1
            shift
            ;;
        *)
            echo "Usage: $0 [--notify]" >&2
            exit 1
            ;;
    esac
done

# === FUNCTIONS ===
get_all_wallpapers() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | sort
}

get_random_wallpaper() {
    local -a candidates=("$@")
    if [[ ${#candidates[@]} -eq 0 ]]; then
        return 1
    fi
    printf '%s\n' "${candidates[@]}" | shuf -n 1
}

update_mru() {
    local selected="$1"
    local tmp_mru
    tmp_mru=$(mktemp)

    # Prepend selected, then append existing MRU entries (excluding selected)
    echo "$selected" > "$tmp_mru"
    if [[ -f "$MRU_FILE" ]]; then
        grep -Fxv "$selected" "$MRU_FILE" >> "$tmp_mru" || true
    fi

    # Keep last 20
    head -n 20 "$tmp_mru" > "$MRU_FILE"
    rm -f "$tmp_mru"
}

# === MAIN ===
# Ensure wallpaper directory exists
if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "[-] Wallpaper directory not found: $WALLPAPER_DIR" >&2
    exit 1
fi

# Collect all wallpapers
readarray -t ALL_WALLPAPERS < <(get_all_wallpapers)
if [[ ${#ALL_WALLPAPERS[@]} -eq 0 ]]; then
    echo "[-] No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

# Load MRU list
readarray -t MRU_ENTRIES < <(cat "$MRU_FILE" 2>/dev/null || true)

# Build candidate list: wallpapers NOT in MRU first
CANDIDATES=()
for wp in "${ALL_WALLPAPERS[@]}"; do
    if ! printf '%s\n' "${MRU_ENTRIES[@]}" | grep -qx "$wp"; then
        CANDIDATES+=("$wp")
    fi
done

# If all wallpapers are in MRU, reset and use all
if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
    CANDIDATES=("${ALL_WALLPAPERS[@]}")
    > "$MRU_FILE"
fi

# Get current wallpaper
CURRENT=""
if [[ -f "$CACHE_FILE" ]]; then
    CURRENT=$(cat "$CACHE_FILE")
fi

# Select new wallpaper (avoid repeating current if possible)
NEW_WALLPAPER=""
for _ in {1..10}; do
    NEW_WALLPAPER=$(get_random_wallpaper "${CANDIDATES[@]}")
    if [[ "$NEW_WALLPAPER" != "$CURRENT" ]]; then
        break
    fi
done

# Fallback if we somehow didn't pick anything
if [[ -z "$NEW_WALLPAPER" ]]; then
    NEW_WALLPAPER="${CANDIDATES[0]}"
fi

# Update caches
echo "$NEW_WALLPAPER" > "$CACHE_FILE"
update_mru "$NEW_WALLPAPER"

# Set wallpaper with awww (swww) if available
if command -v awww &>/dev/null; then
    awww img "$NEW_WALLPAPER" --transition-type wipe --transition-duration 1
fi

# Always run matugen v4 pipeline
if [[ -x "$MATUGEN_SYNC" ]]; then
    bash "$MATUGEN_SYNC" "$NEW_WALLPAPER"
else
    echo "[-] matugen-sync.sh not found or not executable: $MATUGEN_SYNC" >&2
    exit 1
fi

WALLPAPER_NAME=$(basename "$NEW_WALLPAPER")
echo "[+] Wallpaper changed to: $WALLPAPER_NAME"

# Optional notification
if [[ "$NOTIFY" -eq 1 ]]; then
    if command -v notify-send &>/dev/null; then
        notify-send "Wallpaper Changed" "$WALLPAPER_NAME" --icon="preferences-desktop-wallpaper"
    elif command -v makoctl &>/dev/null; then
        # makoctl doesn't have a direct notify command; fallback to notify-send or print
        echo "[+] Wallpaper changed to: $WALLPAPER_NAME"
    fi
fi
