#!/bin/bash
# Boot Optimization Installer
set -e

echo "[*] Installing boot optimizations..."

# Disable slow services
SERVICES=(
    "man-db.service"
    "plocate-updatedb.service"
    "NetworkManager-wait-online.service"
)

for service in "${SERVICES[@]}"; do
    if systemctl is-enabled "$service" > /dev/null 2>&1; then
        echo "    Disabling: $service"
        sudo systemctl disable "$service"
        sudo systemctl mask "$service"
    fi
done

echo "[✓] Boot optimization installed"
echo "    Disabled: ${#SERVICES[@]} services"
