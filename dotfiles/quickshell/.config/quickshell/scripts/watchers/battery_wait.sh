#!/bin/bash
# Battery state wait script
# Polls battery state every 60 seconds (no generic D-Bus API for batteries)
# Also tries upower --monitor if available

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FETCH="$SCRIPT_DIR/battery_fetch.sh"

STATE_FILE="/tmp/qs_battery_state"
"$FETCH" > "$STATE_FILE"

# Prefer upower --monitor if available
if command -v upower &>/dev/null && upower --enumerate &>/dev/null; then
    upower --monitor 2>/dev/null | while read -r line; do
        if echo "$line" | grep -qE '(battery|BAT|hidpp|mouse|keyboard)'; then
            "$FETCH"
        fi
    done
else
    # Fallback: poll every 60 seconds
    while true; do
        sleep 60
        "$FETCH"
    done
fi
