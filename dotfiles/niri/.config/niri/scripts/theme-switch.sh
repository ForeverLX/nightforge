#!/bin/bash
# theme-switch.sh - Unified theme management
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
    demo)
        # Demo mode: disable transparency for client presentations
        echo "Enabling demo mode (opaque windows)..."
        touch /tmp/demo-mode
        # TODO: Implement opacity override logic
        niri msg action load-config-file
        echo "✓ Demo mode ON (manually set opacity to 1.0 in window-rules.kdl)"
        exit 0
        ;;
    normal)
        # Restore normal transparency
        echo "Disabling demo mode (restoring transparency)..."
        rm -f /tmp/demo-mode
        niri msg action load-config-file
        echo "✓ Demo mode OFF"
        exit 0
        ;;
    *)
        echo "Unknown theme: $THEME"
        echo "Available: default, dark, light, demo, normal"
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

# Reload Niri
niri msg action load-config-file
echo "✓ Niri reloaded"

echo ""
echo "Theme: $THEME ✓"
echo "Note: Open new terminal to see Ghostty theme"
