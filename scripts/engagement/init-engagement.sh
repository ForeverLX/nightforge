#!/bin/bash
# Initialize new engagement

ENGAGE_ROOT="$HOME/engage"

if [[ -z "$1" ]]; then
    echo "Usage: $0 <client-name> [target]"
    exit 1
fi

CLIENT="$1"
TARGET="${2:-TBD}"
ENGAGE_DIR="$ENGAGE_ROOT/$CLIENT"

# Create structure
mkdir -p "$ENGAGE_DIR"/{recon,exploit,loot,screenshots,notes}

# Create metadata
cat > "$ENGAGE_DIR/.engagement" << METADATA
CLIENT=$CLIENT
TARGET=$TARGET
START=$(date '+%Y-%m-%d %H:%M:%S')
METADATA

# Create MITRE log
touch "$ENGAGE_DIR/mitre.log"

# Create initial notes
cat > "$ENGAGE_DIR/notes/README.md" << NOTES
# $CLIENT Engagement

**Target:** $TARGET
**Started:** $(date '+%Y-%m-%d')

## Scope

## Timeline

## Findings

NOTES

# Symlink as current
ln -sf "$ENGAGE_DIR" "$ENGAGE_ROOT/current"

echo "✓ Engagement initialized: $ENGAGE_DIR"
echo "→ cd $ENGAGE_DIR"

# Create Obsidian note for engagement
OBSIDIAN_VAULT="$HOME/Documents/Obsidian"  # Adjust path

if [[ -d "$OBSIDIAN_VAULT" ]]; then
    OBSIDIAN_NOTE="$OBSIDIAN_VAULT/Engagements/${CLIENT}.md"
    
    cat > "$OBSIDIAN_NOTE" << NOTE
# ${CLIENT} Engagement

**Target:** ${TARGET}
**Date:** $(date +%Y-%m-%d)
**Status:** Active

## Reconnaissance

## Exploitation

## Findings

## MITRE ATT&CK
- 

## Screenshots
![[screenshot_placeholder.png]]

## Notes
NOTE
    
    echo "Created Obsidian note: Engagements/${CLIENT}.md"
fi
