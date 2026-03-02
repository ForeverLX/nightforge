#!/bin/bash
# install-shell-setup.sh
# Install enhanced Zsh + Tmux for offsec-workstation

set -euo pipefail

echo "========== offsec-workstation Shell Setup =========="
echo ""

# ========== PREREQUISITES ==========
echo "[1/6] Installing prerequisites..."

# Required packages
PACKAGES=(
    "eza"           # Modern ls replacement
    "bat"           # Modern cat replacement
    "fzf"           # Fuzzy finder
    "ripgrep"       # Fast grep
    "fd"            # Modern find
    "tmux"          # Terminal multiplexer
    "git"           # Version control
)

for pkg in "${PACKAGES[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
        echo "  Installing $pkg..."
        sudo pacman -S --noconfirm "$pkg"
    else
        echo "  ✓ $pkg already installed"
    fi
done

# ========== ZINIT (ZSH PLUGIN MANAGER) ==========
echo ""
echo "[2/6] Installing Zinit..."

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
    echo "  ✓ Zinit installed"
else
    echo "  ✓ Zinit already installed"
fi

# ========== TPM (TMUX PLUGIN MANAGER) ==========
echo ""
echo "[3/6] Installing TPM..."

TPM_HOME="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_HOME" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_HOME"
    echo "  ✓ TPM installed"
else
    echo "  ✓ TPM already installed"
fi

# ========== ZSH CONFIG ==========
echo ""
echo "[4/6] Installing Zsh config..."

# Backup existing .zshrc
if [[ -f "$HOME/.zshrc" ]]; then
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
    echo "  ✓ Backed up existing .zshrc"
fi

# Install new .zshrc
cp ~/Downloads/zshrc-enhanced "$HOME/.zshrc"
echo "  ✓ Installed enhanced .zshrc"

# ========== TMUX CONFIG ==========
echo ""
echo "[5/6] Installing Tmux config..."

# Backup existing .tmux.conf
if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup.$(date +%Y%m%d%H%M%S)"
    echo "  ✓ Backed up existing .tmux.conf"
fi

# Install new .tmux.conf
cp ~/Downloads/tmux.conf "$HOME/.tmux.conf"
echo "  ✓ Installed tmux config"

# Create tmux layouts directory
mkdir -p "$HOME/.tmux/layouts"

# Install layouts
cp ~/Downloads/tmux-layout-ad.conf "$HOME/.tmux/layouts/ad-lab.conf"
cp ~/Downloads/tmux-layout-re.conf "$HOME/.tmux/layouts/re-workspace.conf"
cp ~/Downloads/tmux-layout-web.conf "$HOME/.tmux/layouts/web-test.conf"
cp ~/Downloads/tmux-layout-toolbox.conf "$HOME/.tmux/layouts/toolbox.conf"
echo "  ✓ Installed tmux layouts"

# ========== FINALIZE ==========
echo ""
echo "[6/6] Finalizing setup..."

# Install tmux plugins
if command -v tmux &>/dev/null; then
    tmux start-server
    tmux new-session -d
    ~/.tmux/plugins/tpm/scripts/install_plugins.sh
    tmux kill-server
    echo "  ✓ Installed tmux plugins"
fi

# Set zsh as default shell (if not already)
if [[ "$SHELL" != "$(which zsh)" ]]; then
    echo "  ! Run: chsh -s $(which zsh)"
    echo "  ! Then log out and log back in"
fi

echo ""
echo "========== Installation Complete! =========="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal"
echo "  2. Run: p10k configure (to customize prompt)"
echo "  3. Test tmux layouts:"
echo "     - tmux new -s test"
echo "     - Press: Ctrl+A then A (AD layout)"
echo "     - Press: Ctrl+A then R (RE layout)"
echo "     - Press: Ctrl+A then W (Web layout)"
echo "     - Press: Ctrl+A then T (Toolbox layout)"
echo ""
echo "Keybinds:"
echo "  Tmux prefix: Ctrl+A (not Ctrl+B)"
echo "  Split horizontal: Ctrl+A then |"
echo "  Split vertical: Ctrl+A then -"
echo "  Navigate panes: Ctrl+A then h/j/k/l"
echo "  Reload config: Ctrl+A then r"
echo ""
echo "Zsh shortcuts:"
echo "  c ad    - Launch AD container"
echo "  c re    - Launch RE container"
echo "  c web   - Launch web container"
echo "  c tool  - Launch toolbox"
echo ""
echo "Enjoy your enhanced shell! 🚀"
