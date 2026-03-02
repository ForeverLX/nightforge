#!/bin/bash
# theme-switch.sh v2 - Complete theme switching for offsec-workstation
# Switches Niri, Ghostty, and DMS colors based on wallpaper or preset

set -euo pipefail

THEME="${1:-default}"
NIRI_CONFIG="$HOME/.config/niri"
GHOSTTY_CONFIG="$HOME/.config/ghostty"
DMS_CONFIG="$HOME/.config/quickshell/dms"

# ========== THEME SELECTION ==========

case "$THEME" in
    default)
        echo "Switching to default theme..."
        NIRI_THEME="theme-default.kdl"
        GHOSTTY_THEME="config-default"
        ;;
    dark)
        echo "Switching to dark theme (low-light OPSEC)..."
        NIRI_THEME="theme-opsec-dark.kdl"
        GHOSTTY_THEME="config-dark"
        ;;
    light)
        echo "Switching to light theme (high-contrast)..."
        NIRI_THEME="theme-opsec-light.kdl"
        GHOSTTY_THEME="config-light"
        ;;
    wallpaper)
        echo "Generating theme from current wallpaper..."
        WALLPAPER="$2"
        if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
            echo "Error: Wallpaper file required for wallpaper theme"
            echo "Usage: $0 wallpaper <path/to/wallpaper.jpg>"
            exit 1
        fi
        generate_wallpaper_theme "$WALLPAPER"
        return
        ;;
    *)
        echo "Unknown theme: $THEME"
        echo "Available: default, dark, light, wallpaper <path>"
        exit 1
        ;;
esac

# ========== APPLY NIRI THEME ==========

if [ -f "$NIRI_CONFIG/includes/$NIRI_THEME" ]; then
    ln -sf "$NIRI_THEME" "$NIRI_CONFIG/includes/theme-active.kdl"
    echo "✓ Niri theme: $NIRI_THEME"
else
    echo "⚠ Niri theme file not found: $NIRI_THEME"
fi

# ========== APPLY GHOSTTY THEME ==========

if [ -f "$GHOSTTY_CONFIG/$GHOSTTY_THEME" ]; then
    ln -sf "$GHOSTTY_THEME" "$GHOSTTY_CONFIG/config"
    # Reload Ghostty instances
    pkill -SIGUSR1 ghostty 2>/dev/null || true
    echo "✓ Ghostty theme: $GHOSTTY_THEME"
else
    echo "⚠ Ghostty theme file not found: $GHOSTTY_THEME"
fi

# ========== APPLY DMS THEME ==========
# DMS uses matugen - we'll use preset palettes for now

case "$THEME" in
    dark)
        # Dark palette for DMS
        if command -v matugen &>/dev/null; then
            # Use dark preset colors
            matugen color "#1a1a2e" -m dark -t scheme-content \
                -c "$DMS_CONFIG/matugen/configs/" || true
            echo "✓ DMS theme: dark palette"
        fi
        ;;
    light)
        # Light palette for DMS
        if command -v matugen &>/dev/null; then
            matugen color "#f5f5f5" -m light -t scheme-content \
                -c "$DMS_CONFIG/matugen/configs/" || true
            echo "✓ DMS theme: light palette"
        fi
        ;;
esac

# ========== RELOAD CONFIGS ==========

niri msg action load-config-file
echo "✓ Niri config reloaded"

# DMS reload (restart quickshell)
if pgrep -x quickshell >/dev/null; then
    pkill -SIGUSR1 quickshell 2>/dev/null || {
        pkill quickshell
        sleep 0.5
        quickshell &
    }
    echo "✓ DMS reloaded"
fi

echo ""
echo "Theme switched to: $THEME"

# ========== WALLPAPER-BASED GENERATION ==========

generate_wallpaper_theme() {
    local wallpaper="$1"
    
    if ! command -v matugen &>/dev/null; then
        echo "Error: matugen not installed"
        echo "Install with: cargo install matugen"
        exit 1
    fi
    
    echo "Generating colors from: $wallpaper"
    
    # Generate dark-themed colors from wallpaper
    matugen image "$wallpaper" -m dark -t scheme-content \
        -c "$DMS_CONFIG/matugen/configs/" || {
        echo "Error: matugen failed"
        exit 1
    }
    
    # TODO: Parse generated colors and update Niri theme
    # For now, just use dark theme
    NIRI_THEME="theme-opsec-dark.kdl"
    GHOSTTY_THEME="config-dark"
    
    echo "✓ Colors generated (dark mode preference)"
    
    # Set wallpaper
    if command -v swaybg &>/dev/null; then
        pkill swaybg || true
        swaybg -i "$wallpaper" -m fill &
        echo "✓ Wallpaper set"
    fi
}
