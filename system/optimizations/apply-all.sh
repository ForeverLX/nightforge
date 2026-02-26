#!/bin/bash
# Apply All System Optimizations
# offsec-workstation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Applying System Optimizations ==="
echo ""

# Run each module's installer
bash "$SCRIPT_DIR/cpu/install.sh"
bash "$SCRIPT_DIR/network/install.sh"
bash "$SCRIPT_DIR/memory/install.sh"
bash "$SCRIPT_DIR/storage/install.sh"
bash "$SCRIPT_DIR/boot/install.sh"

echo ""
echo "=== All Optimizations Applied ==="
echo ""
echo "⚠️  REBOOT REQUIRED for all changes to take effect"
echo ""
echo "Verify after reboot:"
echo "  perf-status"
echo ""
