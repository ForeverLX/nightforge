#!/bin/bash
# engagement-edit.sh — Edit or create engagement context
# Usage: engagement-edit.sh [engagement-name]

set -euo pipefail

CONFIG_DIR="$HOME/.config/nightforge"
ENGAGEMENT_FILE="$CONFIG_DIR/engagement-context.json"

mkdir -p "$CONFIG_DIR"

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
    if [[ -f "$ENGAGEMENT_FILE" ]]; then
        CURRENT=$(jq -r '.name // empty' "$ENGAGEMENT_FILE" 2>/dev/null || true)
        if [[ -n "$CURRENT" ]]; then
            NAME="$CURRENT"
        else
            read -rp "Engagement name: " NAME
        fi
    else
        read -rp "Engagement name: " NAME
    fi
fi

if [[ -z "$NAME" ]]; then
    echo "No engagement name provided."
    exit 1
fi

# Default template
read -rp "Target domain/IP (optional): " TARGET
read -rp "Notes: " NOTES

cat > "$ENGAGEMENT_FILE" <<EOF
{
  "name": "$NAME",
  "target": "$TARGET",
  "notes": "$NOTES",
  "started": "$(date -Iseconds)",
  "status": "active"
}
EOF

echo "Engagement context updated: $ENGAGEMENT_FILE"
cat "$ENGAGEMENT_FILE"
