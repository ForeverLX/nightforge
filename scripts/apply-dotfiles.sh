#!/bin/bash
# apply-dotfiles.sh - Deploy dotfiles using GNU Stow
# Usage: ./apply-dotfiles.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOTFILES_DIR="$REPO_ROOT/dotfiles"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if stow is installed
if ! command -v stow &>/dev/null; then
    echo -e "${RED}Error: stow is not installed.${NC}"
    echo "Install with: sudo pacman -S stow"
    exit 1
fi

# Check for --dry-run flag
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="-n"
    echo -e "${YELLOW}Dry run mode - no changes will be made${NC}"
fi

# Change to dotfiles directory
cd "$DOTFILES_DIR" || exit 1

# List of packages to stow
PACKAGES=(
    "niri"
    "ghostty"
    "tmux"
    "swappy"
    "operator-terminal"
    "zsh"
    "starship"
    # "nvim" -- pending dedicated session
)

echo -e "${GREEN}Deploying dotfiles with stow...${NC}"

for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$pkg" ]]; then
        echo -e "  → ${YELLOW}$pkg${NC}"
        stow -v $DRY_RUN -t "$HOME" "$pkg"
    else
        echo -e "  ${RED}⚠ Skipping $pkg (directory not found)${NC}"
    fi
done

echo -e "${GREEN}✓ Dotfiles deployed successfully${NC}"
