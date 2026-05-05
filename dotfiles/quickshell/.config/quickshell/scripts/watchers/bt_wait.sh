#!/bin/bash
# Bluetooth state wait script
# Blocks until Bluetooth state changes, outputs new state JSON
# Uses dbus-monitor for BlueZ property changes

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FETCH="$SCRIPT_DIR/bt_fetch.sh"

STATE_FILE="/tmp/qs_bt_state"
"$FETCH" > "$STATE_FILE"

# Listen for BlueZ property changes via D-Bus
dbus-monitor --system "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties'" 2>/dev/null | while read -r line; do
    "$FETCH"
done
