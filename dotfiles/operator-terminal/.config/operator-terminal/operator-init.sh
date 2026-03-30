#!/bin/bash
# Azrael Security Operator Terminal


# Prevent multiple loads
[[ -n "$OPERATOR_TERMINAL_LOADED" ]] && return
export OPERATOR_TERMINAL_LOADED=1

# Performance: disable if SSH session
[[ -n "$SSH_CLIENT" ]] && return

# cmatrix splash — brief animation on terminal open
if command -v cmatrix &>/dev/null && [[ -t 1 ]]; then
    TERM=xterm-256color timeout 3 cmatrix -b -C red 2>/dev/null || true
    clear
fi

# Random banner choice
BANNERS=("AZRAEL SECURITY" "BELOW THE ABSTRACTION")
BANNER="${BANNERS[$((RANDOM % 2))]}"

# Banner (always show)
echo -e "\n\033[0;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\033[1;31m${BANNER}\033[0m"
echo -e "\033[0;31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"

# System info (compact fastfetch with table)
command -v fastfetch &>/dev/null && fastfetch --config compact.jsonc

# Auto-load all modules
for module in ~/.config/operator-terminal/modules/*.sh; do
    [[ -x "$module" ]] && "$module"
done

echo ""
