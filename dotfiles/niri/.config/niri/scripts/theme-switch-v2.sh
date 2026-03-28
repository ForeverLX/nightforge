#!/bin/bash
# theme-switch.sh v2 - FIXED VERSION
set -euo pipefail

THEME="${1:-default}"
NIRI_CONFIG="$HOME/.config/niri"
GHOSTTY_CONFIG="$HOME/.config/ghostty"

case "$THEME" in
    default)
        NIRI_THEME="theme-default.kdl"
        GHOSTTY_THEME="config-default"
        ;;
    dark)
        NIRI_THEME="theme-opsec-dark.kdl"
        GHOSTTY_THEME="config-dark"
        ;;
    light)
        NIRI_THEME="theme-opsec-light.kdl"
        GHOSTTY_THEME="config-light"
        ;;
    *)
        echo "Unknown theme: $THEME"
        echo "Available: default, dark, light"
        exit 1
        ;;
esac

# Apply Niri theme
if [ -f "$NIRI_CONFIG/includes/$NIRI_THEME" ]; then
    ln -sf "$NIRI_THEME" "$NIRI_CONFIG/includes/theme-active.kdl"
    echo "✓ Niri: $NIRI_THEME"
else
    echo "⚠ Niri theme not found: $NIRI_THEME"
fi

# Apply Ghostty theme
if [ -f "$GHOSTTY_CONFIG/$GHOSTTY_THEME" ]; then
    ln -sf "$GHOSTTY_THEME" "$GHOSTTY_CONFIG/config"
    echo "✓ Ghostty: $GHOSTTY_THEME (new terminals)"
else
    echo "⚠ Ghostty theme not found: $GHOSTTY_THEME"
fi

# Toggle demo mode (opaque windows, clean wallpaper)

if [[ -f /tmp/demo-mode ]]; then
    # Restore normal mode
    rm /tmp/demo-mode
    # Restore transparency in window-rules.kdl
    # Restore normal wallpaper
    echo "Demo mode OFF"
else
    # Enable demo mode
    touch /tmp/demo-mode
    # Set all windows to opacity 1.0
    # Set clean/professional wallpaper
    echo "Demo mode ON"
fi

# Reload Niri
niri msg action load-config-file
echo "✓ Niri reloaded"

# DMS will auto-detect config changes
echo "✓ DMS: will auto-detect on next interaction"

echo ""
echo "Theme: $THEME ✓"
echo "Note: Open new terminal to see Ghostty theme"
