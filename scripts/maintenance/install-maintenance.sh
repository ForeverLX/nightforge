#!/bin/bash
# Install offsec-workstation maintenance system
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "═══════════════════════════════════════════════"
echo "  Installing offsec-workstation Maintenance"
echo "═══════════════════════════════════════════════"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# 1. Install script
echo "[1/5] Installing maintenance script..."
install -m 755 "$SCRIPT_DIR/host-maintenance.sh" /usr/local/bin/offsec-maintenance
echo "  ✓ Installed to /usr/local/bin/offsec-maintenance"

# 2. Create log directory
echo "[2/5] Creating log directory..."
mkdir -p /var/log/offsec-workstation
chmod 755 /var/log/offsec-workstation
echo "  ✓ Created /var/log/offsec-workstation"

# 3. Install systemd service
echo "[3/5] Installing systemd service..."
install -m 644 "$SCRIPT_DIR/offsec-maintenance.service" /etc/systemd/system/
echo "  ✓ Installed service"

# 4. Install systemd timer
echo "[4/5] Installing systemd timer..."
install -m 644 "$SCRIPT_DIR/offsec-maintenance.timer" /etc/systemd/system/
echo "  ✓ Installed timer"

# 5. Enable and start timer
echo "[5/5] Enabling timer..."
systemctl daemon-reload
systemctl enable offsec-maintenance.timer
systemctl start offsec-maintenance.timer
echo "  ✓ Timer enabled and started"

echo
echo "═══════════════════════════════════════════════"
echo "  Installation Complete!"
echo "═══════════════════════════════════════════════"
echo
echo "Usage:"
echo "  # Run manually (interactive)"
echo "  offsec-maintenance"
echo
echo "  # Run manually (non-interactive)"  
echo "  sudo offsec-maintenance --non-interactive"
echo
echo "  # Test without making changes"
echo "  offsec-maintenance --dry-run"
echo
echo "  # Check timer status"
echo "  systemctl status offsec-maintenance.timer"
echo
echo "  # View logs"
echo "  journalctl -u offsec-maintenance.service"
echo "  tail -f /var/log/offsec-workstation/maintenance.log"
echo
echo "  # Run timer now (test)"
echo "  sudo systemctl start offsec-maintenance.service"
echo
echo "Automatic maintenance runs every Sunday at 3 AM"
