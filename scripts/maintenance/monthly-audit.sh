#!/bin/bash
# Monthly Organization & Audit
# Run: First Saturday of each month
# Purpose: System audit + interactive organization session

set -e

echo "🗂️  Monthly Organization & Audit - $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Disk Usage Analysis
echo "[1/6] Analyzing disk usage..."
echo ""
df -h / /home | tail -n +2
echo ""
echo "  📁 Largest directories in home:"
du -sh ~/* 2>/dev/null | sort -h | tail -10 | sed 's/^/    /'
echo ""

# 2. Interactive Organization Session
echo "[2/6] Interactive organization..."
echo ""
echo "  Let's organize your workspace!"
echo ""
echo "  Areas to review:"
echo "    [1] ~/Downloads (current size: $(du -sh ~/Downloads 2>/dev/null | awk '{print $1}'))"
echo "    [2] ~/Projects (current size: $(du -sh ~/Projects 2>/dev/null | awk '{print $1}'))"
echo "    [3] ~/engage (current size: $(du -sh ~/engage 2>/dev/null | awk '{print $1}'))"
echo "    [4] ~/Labs (current size: $(du -sh ~/Labs 2>/dev/null | awk '{print $1}'))"
echo "    [5] Container storage"
echo "    [6] Skip organization"
echo ""
read -p "  Which area to organize? [1-6]: " -n 1 -r
echo
echo ""

case $REPLY in
    1)
        echo "  📂 Opening ~/Downloads in ncdu..."
        ncdu ~/Downloads
        ;;
    2)
        echo "  📂 Opening ~/Projects in ncdu..."
        ncdu ~/Projects
        ;;
    3)
        echo "  📂 Opening ~/engage in ncdu..."
        ncdu ~/engage
        ;;
    4)
        echo "  📂 Opening ~/Labs in ncdu..."
        ncdu ~/Labs
        ;;
    5)
        echo "  🐳 Container images:"
        podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}"
        echo ""
        echo "  Old dated images to consider removing:"
        podman images | grep -E "202[0-9]{5}" | sed 's/^/    /'
        echo ""
        read -p "  Open interactive cleanup? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "  Available commands:"
            echo "    podman images              # List all images"
            echo "    podman rmi <image_id>      # Remove specific image"
            echo "    podman image prune -a      # Remove all unused images"
            bash
        fi
        ;;
    *)
        echo "  ⏭  Skipped organization"
        ;;
esac

# 3. Package Statistics
echo ""
echo "[3/6] Package statistics..."
TOTAL_PKG=$(pacman -Q | wc -l)
EXPLICIT_PKG=$(pacman -Qe | wc -l)
DEPS_PKG=$(pacman -Qd | wc -l)
AUR_PKG=$(pacman -Qm | wc -l)
echo "  📦 Total packages: $TOTAL_PKG"
echo "  📦 Explicitly installed: $EXPLICIT_PKG"
echo "  📦 Dependencies: $DEPS_PKG"
echo "  📦 AUR packages: $AUR_PKG"

# 4. Container Health
echo "[4/6] Container health..."
echo "  🐳 Images:"
podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | head -10 | sed 's/^/    /'
echo ""
echo "  💾 Total storage:"
podman system df | sed 's/^/    /'

# 5. Failed Services
echo "[5/6] System services..."
FAILED=$(systemctl --failed --no-legend --no-pager | wc -l)
if [ "$FAILED" -gt 0 ]; then
    echo "  ⚠  $FAILED failed services:"
    systemctl --failed --no-legend --no-pager | sed 's/^/    /'
else
    echo "  ✓ All services running"
fi

# 6. Git Repository Status
echo "[6/6] Git repository health..."
if [ -d ~/Github/offsec-workstation ]; then
    cd ~/Github/offsec-workstation
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
    BRANCH=$(git branch --show-current 2>/dev/null)
    echo "  📝 Branch: $BRANCH"
    echo "  📝 Uncommitted changes: $UNCOMMITTED"
    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo ""
        git status --short | sed 's/^/    /'
        echo ""
        read -p "  Review changes? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git status
            echo ""
            read -p "  Open git shell for committing? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                bash
            fi
        fi
    else
        echo "  ✓ Repository clean"
    fi
fi

echo ""
echo "✨ Monthly audit complete!"
echo ""
echo "📋 Summary:"
echo "  - Disk usage reviewed"
echo "  - Organization session completed"
echo "  - $TOTAL_PKG packages installed"
echo "  - Git repository status checked"
