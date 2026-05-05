#!/bin/bash
# Keyboard layout wait script
# Polls every 10 seconds (layout rarely changes)

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FETCH="$SCRIPT_DIR/kb_fetch.sh"

STATE_FILE="/tmp/qs_kb_state"
"$FETCH" > "$STATE_FILE"

while true; do
    sleep 10
    "$FETCH"
done
