#!/bin/bash
# Bluetooth state fetch script
# Outputs JSON with powered status and connected devices

powered=false
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    powered=true
fi

connected=0
devices_json="["
first=true
while IFS= read -r line; do
    if [[ "$line" =~ ^Device\ ([0-9A-F:]+)\ (.+)$ ]]; then
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        [ "$first" = false ] && devices_json+=", "
        name_esc=$(echo "$name" | sed 's/"/\\"/g')
        devices_json+="{\"name\": \"$name_esc\", \"mac\": \"$mac\"}"
        first=false
        ((connected++))
    fi
done < <(bluetoothctl devices Connected 2>/dev/null)
devices_json+="]"

cat <<JSON
{"powered": $powered, "connected": $connected, "devices": $devices_json}
JSON
