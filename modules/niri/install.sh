#!/bin/bash
# Niri Module Installation Script
# Idempotent - safe to run multiple times

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NIRI_CONFIG_DIR="$HOME/.config/niri"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "Do not run this script as root"
fi

# Banner
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              Niri Module Installation                     ║
║         offsec-workstation - Phase 8.5                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

# Step 1: Install packages
log "Installing required packages..."
PACKAGES=$(grep -vE '^\s*#|^\s*$|^#' "$SCRIPT_DIR/packages.list" | tr '\n' ' ')

if ! pacman -Qi niri &>/dev/null; then
    sudo pacman -S --needed --noconfirm $PACKAGES
    success "Packages installed"
else
    warn "Niri already installed, checking for updates..."
    sudo pacman -S --needed $PACKAGES
fi

# Step 2: Install AUR packages
log "Checking AUR packages..."

if ! command -v yay &>/dev/null; then
    warn "yay not found. Install walker-bin and dank-material-shell manually:"
    echo "  yay -S walker-bin dank-material-shell-git"
else
    if ! pacman -Qi walker-bin &>/dev/null; then
        log "Installing walker-bin..."
        yay -S --needed walker-bin
    fi
    
    # DMS is optional
    read -p "Install Dank Material Shell (DMS)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! pacman -Qi dank-material-shell-git &>/dev/null; then
            yay -S --needed dank-material-shell-git
        fi
    else
        warn "Skipping DMS, will use Waybar as fallback"
    fi
fi

# Step 3: Create config directory structure
log "Setting up Niri config directory..."
mkdir -p "$NIRI_CONFIG_DIR"/{includes,scripts}

# Step 4: Link dotfiles
log "Linking Niri configuration..."

if [[ -f "$NIRI_CONFIG_DIR/config.kdl" ]] && [[ ! -L "$NIRI_CONFIG_DIR/config.kdl" ]]; then
    warn "Existing config.kdl found, backing up..."
    mv "$NIRI_CONFIG_DIR/config.kdl" "$NIRI_CONFIG_DIR/config.kdl.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Link main config
ln -sf "$REPO_ROOT/dotfiles/niri/config.kdl" "$NIRI_CONFIG_DIR/config.kdl"

# Link includes
for include in "$REPO_ROOT/dotfiles/niri/includes/"*; do
    if [[ -f "$include" ]]; then
        ln -sf "$include" "$NIRI_CONFIG_DIR/includes/$(basename "$include")"
    fi
done

# Link scripts
for script in "$REPO_ROOT/dotfiles/niri/scripts/"*; do
    if [[ -f "$script" ]]; then
        ln -sf "$script" "$NIRI_CONFIG_DIR/scripts/$(basename "$script")"
        chmod +x "$script"
    fi
done

success "Configuration linked"

# Step 5: Set up display manager
log "Configuring display manager..."

if systemctl is-enabled --quiet sddm; then
    warn "SDDM detected. Niri session will be available at login."
elif systemctl is-enabled --quiet gdm; then
    warn "GDM detected. Niri session will be available at login."
elif systemctl is-enabled --quiet lightdm; then
    warn "LightDM detected. Niri session will be available at login."
else
    warn "No display manager detected. Niri will be available via 'niri-session'"
fi

# Step 6: Create local.kdl if it doesn't exist
if [[ ! -f "$NIRI_CONFIG_DIR/includes/local.kdl" ]]; then
    log "Creating local.kdl for machine-specific settings..."
    cat > "$NIRI_CONFIG_DIR/includes/local.kdl" << 'EOF'
// Local machine-specific configuration
// This file is gitignored and won't be synced

// Example: Monitor configuration
// output "HDMI-A-1" {
//     mode "1920x1080@60"
//     position x=0 y=0
// }

// Example: Custom keybinds
// binds {
//     Mod+Alt+X { spawn "custom-script"; }
// }
EOF
    success "Created local.kdl template"
fi

# Step 7: Final steps
echo ""
log "Installation complete! Next steps:"
echo ""
echo "  1. Logout and select 'Niri' at the login screen"
echo "  2. Or run: niri-session"
echo "  3. Sway remains available as fallback"
echo ""
warn "First launch tips:"
echo "  - Super+D to open launcher"
echo "  - Super+Return for terminal"
echo "  - Super+Slash for keybind help"
echo ""
success "Ready to switch to Niri!"
