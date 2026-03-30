#!/bin/bash
# Obsidian vault status — azrael-vault

VAULT_PATH="$HOME/Documents/azrael-vault"

if [[ ! -d "$VAULT_PATH" ]]; then
    return
fi

NOTE_COUNT=$(find "$VAULT_PATH" -name "*.md" -not -path "*/\.*" 2>/dev/null | wc -l)

# Daily log path uses new hybrid PARA structure
DAILY_NOTE=$(find "$VAULT_PATH/00-Operator-Log" -name "*.md" -type f \
    -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | awk '{print $2}' | \
    xargs -r basename 2>/dev/null)

if [[ -n "$DAILY_NOTE" ]]; then
    echo -e "\033[0;35m[📓] Obsidian:\033[0m $NOTE_COUNT notes (latest: ${DAILY_NOTE%.md})"
else
    echo -e "\033[0;35m[📓] Obsidian:\033[0m $NOTE_COUNT notes"
fi
