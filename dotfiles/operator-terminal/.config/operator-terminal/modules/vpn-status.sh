#!/bin/bash
# VPN / mesh status — WireGuard wg0 detection

# Check if wg0 interface exists and is UP (no sudo required)
if ip link show wg0 2>/dev/null | grep -q "state UP"; then
    WG_IP=$(ip -4 addr show wg0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "\033[0;32m[✓] Mesh:\033[0m wg0 UP ($WG_IP)"
elif ip link show wg0 &>/dev/null; then
    echo -e "\033[0;33m[~] Mesh:\033[0m wg0 exists but not UP"
else
    echo -e "\033[0;31m[✗] Mesh:\033[0m wg0 not found — run wgup"
fi

# Legacy VPN (tun/tap) — for HTB/lab VPN connections
VPN_IFACE=$(ip link 2>/dev/null | grep -oE 'tun[0-9]+|tap[0-9]+' | head -1)
if [[ -n "$VPN_IFACE" ]]; then
    VPN_IP=$(ip -4 addr show "$VPN_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "\033[0;32m[✓] VPN:\033[0m $VPN_IFACE ($VPN_IP)"
fi
