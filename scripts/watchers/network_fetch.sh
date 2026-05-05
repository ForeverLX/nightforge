#!/bin/bash
# Output: {"icon":"NET_ICON","status":"ETH|WiFi|VPN|Down","ssid":"SSID_OR_EMPTY"}

if nmcli -t -f TYPE,STATE d 2>/dev/null | grep -q '^ethernet:connected$'; then
    echo '{"icon":"󰛳","status":"ETH","ssid":""}'
elif nmcli -t -f TYPE,STATE d 2>/dev/null | grep -q '^wifi:connected$'; then
    ssid=$(nmcli -t -f ACTIVE,SSID d wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
    echo "{\"icon\":\"󰤨\",\"status\":\"WiFi\",\"ssid\":\"$ssid\"}"
elif wg show wg0 2>/dev/null | grep -q interface; then
    echo '{"icon":"󰒃","status":"VPN","ssid":""}'
else
    echo '{"icon":"󰤭","status":"Down","ssid":""}'
fi
