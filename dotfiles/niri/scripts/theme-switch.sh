#!/bin/bash
# Theme Switcher for Niri
# Quick theme changes for OPSEC scenarios

set -euo pipefail

THEME="${1:-default}"
NIRI_CONFIG="$HOME/.config/niri"

case "$THEME" in
    default)
        echo "Switching to default theme..."
        ln -sf "$NIRI_CONFIG/includes/theme-default.kdl" "$NIRI_CONFIG/includes/theme-active.kdl"
        ;;
    dark)
        echo "Switching to OPSEC dark theme (low-light)..."
        # TODO: Create theme-opsec-dark.kdl
        ln -sf "$NIRI_CONFIG/includes/theme-default.kdl" "$NIRI_CONFIG/includes/theme-active.kdl"
        ;;
    light)
        echo "Switching to OPSEC light theme (high-contrast)..."
        # TODO: Create theme-opsec-light.kdl
        ln -sf "$NIRI_CONFIG/includes/theme-default.kdl" "$NIRI_CONFIG/includes/theme-active.kdl"
        ;;
    *)
        echo "Unknown theme: $THEME"
        echo "Available: default, dark, light"
        exit 1
        ;;
esac

# Reload Niri config
niri msg action reload-config

# TODO: Also update Waybar theme
# TODO: Update terminal colors
# TODO: Change wallpaper

echo "Theme switched to: $THEME"
