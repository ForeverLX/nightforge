#!/bin/bash
# Network Optimization Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing network optimization..."

# Backup existing configs
sudo cp /etc/sysctl.d/99-network-performance.conf \
    /etc/sysctl.d/99-network-performance.conf.backup 2>/dev/null || true
sudo cp /etc/udev/rules.d/99-network-rps.rules \
    /etc/udev/rules.d/99-network-rps.rules.backup 2>/dev/null || true

# Install sysctl config
sudo cp "$SCRIPT_DIR/99-network-performance.conf" /etc/sysctl.d/

# Install udev rules
sudo cp "$SCRIPT_DIR/99-network-rps.rules" /etc/udev/rules.d/

# Apply immediately
sudo sysctl --system > /dev/null 2>&1
sudo udevadm control --reload-rules

echo "[✓] Network optimization installed"
echo "    Congestion control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "    Max buffer: $(sysctl -n net.core.rmem_max)"
