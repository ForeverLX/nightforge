#!/bin/bash
# Network speed check (simplified)

# Get active interface
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [[ -n "$IFACE" ]]; then
    # Check speed from ethtool (if available)
    if command -v ethtool &>/dev/null; then
        SPEED=$(ethtool "$IFACE" 2>/dev/null | grep Speed | awk '{print $2}')
        [[ -n "$SPEED" ]] && echo -e "\033[0;36m[≈] Network:\033[0m $IFACE @ $SPEED"
    fi
fi
