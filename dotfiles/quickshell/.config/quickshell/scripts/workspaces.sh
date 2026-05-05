#!/bin/bash
# Niri workspace daemon
# Outputs JSON array of workspaces for QML ListModel
# Format: [{"id": 1, "name": "1", "active": true, "occupied": true}, ...]

# Check if niri is running
if ! command -v niri &>/dev/null || ! niri msg --json workspaces &>/dev/null; then
    echo '[]'
    exit 0
fi

active=$(niri msg --json active-workspace 2>/dev/null | jq '.id' 2>/dev/null)
if [ -z "$active" ] || [ "$active" = "null" ]; then
    active=-1
fi

niri msg --json workspaces 2>/dev/null | \
    jq --argjson active "$active" \
    '[.[] | {id: .id, name: (.name | tostring), active: (.id == $active), occupied: (.windows > 0)}]' 2>/dev/null || \
    echo '[]'
