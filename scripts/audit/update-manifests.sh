#!/bin/bash
# update-manifests.sh - Generate package manifests from current system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFESTS_DIR="$REPO_ROOT/manifests"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Generating package manifests...${NC}"

# Full explicit packages
pacman -Qet > "$MANIFESTS_DIR/explicit-packages.txt"
echo -e "${GREEN}✓ explicit-packages.txt${NC}"

# AUR packages
pacman -Qm > "$MANIFESTS_DIR/aur-packages.txt"
echo -e "${GREEN}✓ aur-packages.txt${NC}"

# Base system (core packages everyone needs)
pacman -Qqg base base-devel > "$MANIFESTS_DIR/base.pacman.txt" 2>/dev/null || true
echo -e "${GREEN}✓ base.pacman.txt${NC}"

# You can add more profile-specific filtering here
# For now, just copy explicit as starting point
cp "$MANIFESTS_DIR/explicit-packages.txt" "$MANIFESTS_DIR/host-packages.txt"
echo -e "${GREEN}✓ host-packages.txt (copy of explicit)${NC}"

echo -e "${GREEN}Done. Review and edit profile-specific manifests manually.${NC}"
