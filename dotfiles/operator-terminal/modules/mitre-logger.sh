#!/bin/bash
# MITRE ATT&CK technique logger

# Only show if in engagement
ENGAGE_ROOT="$HOME/engage"
if [[ "$PWD" == "$ENGAGE_ROOT"/* ]]; then
    MITRE_LOG="$PWD/mitre.log"
    
    if [[ -f "$MITRE_LOG" ]]; then
        LAST_TECHNIQUE=$(tail -1 "$MITRE_LOG" | awk '{print $3}')
        COUNT=$(wc -l < "$MITRE_LOG")
        echo -e "\033[0;35m[⚔] MITRE:\033[0m $COUNT techniques logged (last: $LAST_TECHNIQUE)"
    fi
fi
