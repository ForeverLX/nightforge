#!/bin/bash
# Network state wait script
# Blocks until network state changes, outputs new state JSON
# Uses nmcli monitor for real-time network events

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FETCH="$SCRIPT_DIR/network_fetch.sh"

STATE_FILE="/tmp/qs_network_state"
"$FETCH" > "$STATE_FILE"

# nmcli monitor outputs lines on device state changes
nmcli monitor 2>/dev/null | while read -r line; do
    # Filter for relevant device changes
    if echo "$line" | grep -qE '(wifi|ethernet|vpn|connected|disconnected)'; then
        "$FETCH"
    fi
done
