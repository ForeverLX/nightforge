#!/bin/bash
# Create Engagement Directory
# Usage: ./scripts/engagement/create-engagement.sh <name>

set -euo pipefail

ENGAGEMENT_NAME="${1:-}"
BASE_DIR="${ENGAGE_DIR:-$HOME/engage}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <engagement-name>

Creates a properly structured engagement directory with correct permissions
for use with offsec containers.

Examples:
  $(basename "$0") target-company-2026
  $(basename "$0") webapp-pentest

Directory structure:
  ~/engage/<name>/
    ├── recon/       # Reconnaissance output
    ├── exploit/     # Exploitation work
    ├── loot/        # Captured data
    ├── notes/       # Markdown notes
    └── reports/     # Final reports

Permissions: 755 (rwxr-xr-x) - allows container access
EOF
    exit 1
}

[[ -z "$ENGAGEMENT_NAME" ]] && usage

ENGAGEMENT_DIR="$BASE_DIR/$ENGAGEMENT_NAME"

if [[ -d "$ENGAGEMENT_DIR" ]]; then
    echo -e "${YELLOW}Warning: Directory already exists: $ENGAGEMENT_DIR${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

echo -e "${BLUE}Creating engagement directory structure...${NC}"

# Create directories with 755 permissions
mkdir -p "$ENGAGEMENT_DIR"/{recon,exploit,loot,notes,reports}
chmod 755 "$ENGAGEMENT_DIR"
chmod 755 "$ENGAGEMENT_DIR"/{recon,exploit,loot,notes,reports}

# Create initial notes file
cat > "$ENGAGEMENT_DIR/notes/README.md" << EOF
# Engagement: $ENGAGEMENT_NAME

**Created**: $(date '+%Y-%m-%d %H:%M:%S')  
**Operator**: $(whoami)

## Objectives

- [ ] Initial reconnaissance
- [ ] Vulnerability identification
- [ ] Exploitation
- [ ] Privilege escalation
- [ ] Lateral movement
- [ ] Data exfiltration
- [ ] Persistence
- [ ] Cleanup

## Timeline

| Date | Phase | Notes |
|------|-------|-------|
| $(date '+%Y-%m-%d') | Recon | Starting reconnaissance |

## Findings

### Critical

### High

### Medium

### Low

## Commands Run

\`\`\`bash
# Add commands here as you work
\`\`\`

## References

- 
EOF

chmod 644 "$ENGAGEMENT_DIR/notes/README.md"

echo -e "${GREEN}✓ Engagement directory created:${NC} $ENGAGEMENT_DIR"
echo -e "${GREEN}✓ Permissions set:${NC} 755 (rwxr-xr-x)"
echo ""
echo -e "${BLUE}Quick start:${NC}"
echo "  cd $ENGAGEMENT_DIR"
echo "  ~/Github/offsec-workstation/modules/container/scripts/container.sh run web"
echo ""
echo -e "${BLUE}Or with Zellij:${NC}"
echo "  cd $ENGAGEMENT_DIR"
echo "  ~/Github/offsec-workstation/scripts/zellij/zellij-launch.sh web recon"
