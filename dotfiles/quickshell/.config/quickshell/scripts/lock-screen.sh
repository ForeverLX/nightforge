#!/bin/bash
# NightForge lock screen launcher
# Tries lockers in order: gtklock > swaylock > simple fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try gtklock first (best theming support)
if command -v gtklock >/dev/null 2>&1; then
    exec gtklock \
        --style "${SCRIPT_DIR}/../../../gtklock/style.css" \
        --show-clock \
        --show-user-image \
        --start-hidden \
        "$@"
fi

# Fallback to swaylock-effects or swaylock
if command -v swaylock >/dev/null 2>&1; then
    exec swaylock \
        --color 1e1e2e \
        --clock \
        --datestr "%a, %b %d" \
        --font "JetBrains Mono" \
        --inside-color 313244 \
        --line-color cba6f7 \
        --ring-color cba6f7 \
        --inside-ver-color 89b4fa \
        --ring-ver-color 89b4fa \
        --inside-wrong-color f38ba8 \
        --ring-wrong-color f38ba8 \
        --key-hl-color a6e3a1 \
        --text-color cdd6f4 \
        --text-ver-color cdd6f4 \
        --text-wrong-color cdd6f4 \
        "$@"
fi

# Final fallback: notify and do nothing
echo "No lock screen tool found. Install gtklock or swaylock."
exit 1
