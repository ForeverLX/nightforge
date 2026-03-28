#!/bin/bash
# container-focus.sh - Focus or spawn container windows
# Usage: container-focus.sh <profile> <window-title-part>
# Example: container-focus.sh ad offsec-ad

set -euo pipefail

PROFILE="$1"
TITLE_MATCH="$2"

if [ -z "$PROFILE" ] || [ -z "$TITLE_MATCH" ]; then
    echo "Usage: $0 <profile> <window-title-part>"
    exit 1
fi

# Check if any window contains the title match
WIN_ID=$(niri msg windows | jq -r ".[] | select(.title | contains(\"$TITLE_MATCH\")) | .id" | head -1)

if [ -n "$WIN_ID" ]; then
    # Focus existing window
    niri msg action focus-window "$WIN_ID"
    echo "Focused existing $PROFILE window"
else
    # Launch new container
    ~/.config/niri/scripts/container-launch.sh "$PROFILE"
    echo "Launched new $PROFILE container"
fi
