#!/bin/bash
# Memory Optimization Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing memory optimization..."

# Backup existing configs
sudo cp /etc/sysctl.d/99-memory-performance.conf \
    /etc/sysctl.d/99-memory-performance.conf.backup 2>/dev/null || true
sudo cp /etc/tmpfiles.d/hugepages.conf \
    /etc/tmpfiles.d/hugepages.conf.backup 2>/dev/null || true

# Install sysctl config
sudo cp "$SCRIPT_DIR/99-memory-performance.conf" /etc/sysctl.d/

# Install tmpfiles config
sudo cp "$SCRIPT_DIR/hugepages.conf" /etc/tmpfiles.d/

# Apply immediately
sudo sysctl --system > /dev/null 2>&1
sudo systemd-tmpfiles --create

echo "[✓] Memory optimization installed"
echo "    Swappiness: $(sysctl -n vm.swappiness)"
echo "    THP enabled: $(cat /sys/kernel/mm/transparent_hugepage/enabled)"
