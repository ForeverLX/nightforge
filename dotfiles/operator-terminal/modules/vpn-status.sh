#!/bin/bash
# VPN detection (improved)

# Check for any tun/tap interface
VPN_IFACE=$(ip link 2>/dev/null | grep -oE 'tun[0-9]+|tap[0-9]+' | head -1)

if [[ -n "$VPN_IFACE" ]]; then
    VPN_IP=$(ip -4 addr show "$VPN_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    echo -e "\033[0;32m[✓] VPN:\033[0m Connected via $VPN_IFACE ($VPN_IP)"
else
    echo -e "\033[0;31m[✗] VPN:\033[0m Disconnected"
fi
