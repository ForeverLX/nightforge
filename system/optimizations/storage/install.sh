#!/bin/bash
# Storage I/O Optimization Installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[*] Installing storage optimization..."

# Backup existing
sudo cp /etc/udev/rules.d/99-nvme-performance.rules \
    /etc/udev/rules.d/99-nvme-performance.rules.backup 2>/dev/null || true

# Install udev rules
sudo cp "$SCRIPT_DIR/99-nvme-performance.rules" /etc/udev/rules.d/

# Apply immediately
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "[✓] Storage optimization installed"
echo "    NVMe scheduler: $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo 'N/A')"
