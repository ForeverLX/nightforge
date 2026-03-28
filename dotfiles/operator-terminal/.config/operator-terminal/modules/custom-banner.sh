#!/bin/bash
# Custom contextual banner at bottom

# Color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo ""  # Spacing

# Check for engagement context
if [[ -n "$OFFSEC_CURRENT_ENGAGEMENT" ]]; then
    echo -e "${RED}╔════════════════════════════════════════╗${RESET}"
    echo -e "${RED}║${RESET} ${YELLOW}⚡ ACTIVE ENGAGEMENT: $OFFSEC_CURRENT_ENGAGEMENT${RESET}"
    
    # Check for OPSEC mode
    if [[ -f "$HOME/engage/current/.opsec" ]]; then
        echo -e "${RED}║${RESET} ${RED}⚠  OPSEC MODE ENABLED${RESET}"
    fi
    
    echo -e "${RED}╚════════════════════════════════════════╝${RESET}"
fi

# Random tip/reminder (10% chance)
if (( RANDOM % 10 == 0 )); then
    TIPS=(
        "Remember to log MITRE techniques (mitre log)"
        "Check container status before pivoting (podman ps)"
        "Document findings in Obsidian vault"
        "Verify VPN before starting scans"
        "Clean up containers after testing (cleanup.sh)"
    )
    TIP="${TIPS[$((RANDOM % ${#TIPS[@]}))]}"
    echo -e "${CYAN}💡 Tip: ${TIP}${RESET}"
fi
