#!/bin/bash
# Obsidian vault detection and stats

VAULT_PATH="$HOME/Documents/Personal/Notes/CRTO-Journey-Vault"

if [[ -d "$VAULT_PATH" ]]; then
    NOTE_COUNT=$(find "$VAULT_PATH" -name "*.md" -not -path "*/\.*" | wc -l)
    DAILY_NOTE=$(find "$VAULT_PATH/01-Daily-Logs" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | awk '{print $2}' | xargs basename 2>/dev/null)
    
    if [[ -n "$DAILY_NOTE" ]]; then
        echo -e "\033[0;35m[📓] Obsidian:\033[0m $NOTE_COUNT notes (latest: ${DAILY_NOTE%.md})"
    else
        echo -e "\033[0;35m[📓] Obsidian:\033[0m $NOTE_COUNT notes"
    fi
fi
