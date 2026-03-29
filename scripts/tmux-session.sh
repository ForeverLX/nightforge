#!/bin/bash
# tmux-session.sh - Unified tmux session launcher
# Usage: tmux-session.sh [layout-name]
#   If layout-name is provided, launch that layout directly.
#   If no layout-name, show interactive chooser via fzf.

set -euo pipefail

LAYOUT_DIR="$HOME/.config/tmux/layouts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to show available layouts
show_layouts() {
    echo -e "${YELLOW}Available tmux layouts:${NC}"
    for layout in "$LAYOUT_DIR"/*.conf; do
        if [[ -f "$layout" ]]; then
            name=$(basename "$layout" .conf)
            echo "  $name"
        fi
    done
}

# Function to launch a layout
launch_layout() {
    local layout_name="$1"
    local layout_file="$LAYOUT_DIR/$layout_name.conf"
    
    if [[ ! -f "$layout_file" ]]; then
        echo -e "${RED}Error: Layout '$layout_name' not found.${NC}"
        show_layouts
        exit 1
    fi
    
    # Check if tmux config is accessible
    if [[ ! -f "$HOME/.config/tmux/tmux.conf" ]]; then
        echo -e "${YELLOW}Warning: tmux config not found at ~/.config/tmux/tmux.conf${NC}"
        echo "Create symlink: ln -s ~/Github/nightforge/dotfiles/tmux/.config/tmux/tmux.conf ~/.config/tmux/tmux.conf"
    fi
    
    # Check if tmux is running
    if tmux has-session -t "$layout_name" 2>/dev/null; then
        echo -e "${YELLOW}Session '$layout_name' already exists. Attaching...${NC}"
        tmux attach -t "$layout_name"
    else
        echo -e "${GREEN}Creating new tmux session '$layout_name'...${NC}"
        # Create session with error checking
        if tmux new-session -d -s "$layout_name" \; source-file "$layout_file" 2>&1 | tee /tmp/tmux-error.log; then
            tmux attach -t "$layout_name"
        else
            echo -e "${RED}Failed to create session. Check /tmp/tmux-error.log${NC}"
            cat /tmp/tmux-error.log
            # Clean up the failed session
            tmux kill-session -t "$layout_name" 2>/dev/null || true
            exit 1
        fi
    fi
}

# Main logic
if [[ $# -eq 1 ]]; then
    # Direct launch with layout name
    launch_layout "$1"
elif [[ $# -eq 0 ]]; then
    # Interactive chooser with fzf
    if ! command -v fzf &>/dev/null; then
        echo -e "${RED}Error: fzf not found. Please install fzf or provide a layout name.${NC}"
        show_layouts
        exit 1
    fi
    
    # Build list of layout names for fzf
    layout_list=""
    for layout in "$LAYOUT_DIR"/*.conf; do
        if [[ -f "$layout" ]]; then
            layout_list+="$(basename "$layout" .conf)\n"
        fi
    done
    
    selected=$(echo -e "$layout_list" | fzf --prompt="Select tmux layout: " --height=10 --reverse)
    
    if [[ -n "$selected" ]]; then
        launch_layout "$selected"
    else
        echo -e "${YELLOW}No layout selected.${NC}"
        exit 0
    fi
else
    echo "Usage: $0 [layout-name]"
    echo ""
    show_layouts
    exit 1
fi
