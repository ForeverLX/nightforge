#!/bin/bash
# focus-or-spawn.sh - ACTUALLY FIXED VERSION
set -euo pipefail

MODE=""
PATTERN=""
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --app-id)
            MODE="app-id"
            PATTERN="$2"
            shift 2
            ;;
        --title)
            MODE="title"
            PATTERN="$2"
            shift 2
            ;;
        *)
            COMMAND="$*"
            break
            ;;
    esac
done

if [ -z "$MODE" ] || [ -z "$PATTERN" ] || [ -z "$COMMAND" ]; then
    echo "Usage: $0 --app-id <pattern> <command>"
    exit 1
fi

# Get window ID (using -j for JSON)
case "$MODE" in
    app-id)
        WIN_ID=$(niri msg -j windows | jq -r ".[] | select(.app_id | contains(\"$PATTERN\")) | .id" | head -1)
        ;;
    title)
        WIN_ID=$(niri msg -j windows | jq -r ".[] | select(.title | contains(\"$PATTERN\")) | .id" | head -1)
        ;;
esac

if [ -n "$WIN_ID" ]; then
    # FIX: Use --id flag
    niri msg action focus-window --id "$WIN_ID"
    echo "Focused existing window: $WIN_ID"
else
    echo "No matching window, spawning: $COMMAND"
    eval "$COMMAND" &
fi
