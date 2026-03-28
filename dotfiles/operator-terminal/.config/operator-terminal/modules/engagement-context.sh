#!/bin/bash
# Engagement context detection

ENGAGE_ROOT="$HOME/engage"

# Check if in engagement directory
if [[ "$PWD" == "$ENGAGE_ROOT"/* ]]; then
    ENGAGEMENT=$(echo "$PWD" | sed "s|$ENGAGE_ROOT/||" | cut -d'/' -f1)
    
    # Check if it's current symlink
    if [[ -L "$ENGAGE_ROOT/current" ]]; then
        CURRENT=$(readlink "$ENGAGE_ROOT/current" | xargs basename)
        if [[ "$ENGAGEMENT" == "$CURRENT" ]]; then
            echo -e "\033[1;33m[⚡] ENGAGEMENT:\033[0m $ENGAGEMENT (active)"
        else
            echo -e "\033[0;33m[~] ENGAGEMENT:\033[0m $ENGAGEMENT (archived)"
        fi
    else
        echo -e "\033[0;33m[~] ENGAGEMENT:\033[0m $ENGAGEMENT"
    fi
    
    # Check for engagement metadata
    if [[ -f ".engagement" ]]; then
        TARGET=$(grep "^TARGET=" ".engagement" | cut -d'=' -f2)
        [[ -n "$TARGET" ]] && echo -e "\033[0;36m[→] Target:\033[0m $TARGET"
    fi
fi
