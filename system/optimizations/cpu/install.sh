#!/bin/bash
# CPU Performance Optimization Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing CPU performance optimization..."

# Backup if exists
if [ -f /etc/systemd/system/cpu-performance.service ]; then
    sudo cp /etc/systemd/system/cpu-performance.service \
        /etc/systemd/system/cpu-performance.service.backup
fi

# Install service
sudo cp "$SCRIPT_DIR/cpu-performance.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cpu-performance.service
sudo systemctl start cpu-performance.service

echo "[✓] CPU performance optimization installed"
echo "    Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
