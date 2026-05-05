#!/bin/bash
# Network state fetch script
# Outputs JSON with WiFi, VPN, and Ethernet status

# WiFi: check active connection
wifi_connected=false
wifi_ssid=""
wifi_strength=0

while IFS=':' read -r type state name; do
    if [ "$type" = "wifi" ] && [ "$state" = "connected" ]; then
        wifi_connected=true
        wifi_ssid="$name"
        # Get signal strength from the active wifi connection
        sig=$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | grep '^\*' | head -1 | cut -d: -f2)
        [ -n "$sig" ] && wifi_strength="$sig"
        break
    fi
done < <(nmcli -t -f TYPE,STATE,NAME device status 2>/dev/null)

# VPN: check wireguard or other VPN interfaces
vpn=false
if ip link show wg0 2>/dev/null | grep -q "UP"; then
    vpn=true
elif nmcli -t -f TYPE,STATE connection show --active 2>/dev/null | grep -q "vpn:activated"; then
    vpn=true
fi

# Ethernet
eth=false
while IFS=':' read -r type state name; do
    if [ "$type" = "ethernet" ] && [ "$state" = "connected" ]; then
        eth=true
        break
    fi
done < <(nmcli -t -f TYPE,STATE,NAME device status 2>/dev/null)

# Escape SSID for JSON
wifi_ssid_esc=$(echo "$wifi_ssid" | sed 's/"/\\"/g')

cat <<JSON
{"wifi": {"connected": $wifi_connected, "ssid": "$wifi_ssid_esc", "strength": $wifi_strength}, "vpn": $vpn, "eth": $eth}
JSON
