#!/bin/bash
# scripts/audit/package-audit.sh
# Phase 10: Comprehensive Package Audit
# Run with: ./scripts/audit/package-audit.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

MANIFEST_DIR="manifests"
REPORT_DIR="docs/audits/package"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/audit-${TIMESTAMP}.md"

mkdir -p "${REPORT_DIR}"

# Helper functions
print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[+]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[-]${NC} $1"; }

# Start report
cat > "${REPORT_FILE}" << EOF
# Package Audit Report: ${TIMESTAMP}

## System Overview
- Hostname: $(hostname)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Total Packages: $(pacman -Q | wc -l)

EOF

# 1. Compare against manifest
print_status "Step 1: Comparing installed packages against manifest..."
if [[ -f "${MANIFEST_DIR}/host-packages.txt" ]]; then
    # Get list of explicitly installed packages (not dependencies)
    pacman -Qqe > /tmp/explicit-packages.tmp
    
    # Find packages in manifest but not installed
    comm -23 <(sort "${MANIFEST_DIR}/host-packages.txt") <(sort /tmp/explicit-packages.tmp) > /tmp/missing-from-system.tmp
    
    # Find packages installed but not in manifest
    comm -13 <(sort "${MANIFEST_DIR}/host-packages.txt") <(sort /tmp/explicit-packages.tmp) > /tmp/extra-on-system.tmp
    
    {
        echo "## Manifest Comparison"
        echo ""
        echo "### Packages in Manifest but NOT Installed (Missing)"
        if [[ -s /tmp/missing-from-system.tmp ]]; then
            cat /tmp/missing-from-system.tmp
        else
            echo "None - all manifest packages are installed."
        fi
        echo ""
        echo "### Packages Installed but NOT in Manifest (Extra)"
        if [[ -s /tmp/extra-on-system.tmp ]]; then
            cat /tmp/extra-on-system.tmp
        else
            echo "None - no extra explicit packages found."
        fi
        echo ""
    } >> "${REPORT_FILE}"
    
    print_success "Comparison complete. Review extras: extra-on-system.tmp"
else
    print_warning "No host-packages.txt manifest found. Creating initial list..."
    pacman -Qqe > "${MANIFEST_DIR}/host-packages.txt"
    print_success "Initial manifest created at ${MANIFEST_DIR}/host-packages.txt"
fi

# 2. Dependency analysis: Find packages that are dependencies of others
print_status "Step 2: Identifying packages that are required dependencies..."
{
    echo "## Dependency Analysis"
    echo ""
    echo "### Packages that are dependencies of others (can potentially be removed if not needed explicitly)"
    echo "\`\`\`"
    pacman -Qqdt
    echo "\`\`\`"
    echo ""
    echo "### Orphaned packages (no dependencies, no explicit install)"
    echo "\`\`\`"
    pacman -Qqtd
    echo "\`\`\`"
    echo ""
} >> "${REPORT_FILE}"

# 3. Package size analysis
print_status "Step 3: Analyzing package sizes..."
{
    echo "## Package Size Analysis"
    echo ""
    echo "### Top 50 Largest Packages"
    echo "\`\`\`"
    LANG=C pacman -Qi | awk -F': ' '/^Name/{name=$2} /^Installed Size/{size=$2; sub(/ [^ ]+$/, "", size); printf "%s %s\n", name, size}' | sort -hrk2,2 | head -50
    echo "\`\`\`"
    echo ""
} >> "${REPORT_FILE}"

# 4. Package category analysis (grouping by purpose)
print_status "Step 4: Categorizing packages..."
{
    echo "## Package Categories"
    echo ""
    
    # Common categories for offensive security workstation
    categories=(
        "Desktop Environment"
        "Window Manager (Niri/Sway)"
        "Terminal & Shell"
        "Development Tools"
        "Network Tools"
        "Reverse Engineering"
        "Web Testing"
        "Exploitation Tools"
        "Utils & System"
    )
    
    for category in "${categories[@]}"; do
        echo "### ${category}"
        echo "\`\`\`"
        # This is a heuristic - you'll need to refine based on actual package names
        case "${category}" in
            "Desktop Environment") pacman -Q | grep -E 'gnome|kde|xfce|mate|cinnamon' | sort || echo "None identified";;
            "Window Manager (Niri/Sway)") pacman -Q | grep -E 'niri|sway|wlroots|wayland' | sort || echo "None identified";;
            "Terminal & Shell") pacman -Q | grep -E 'zsh|bash|fish|tmux|alacritty|kitty' | sort || echo "None identified";;
            "Development Tools") pacman -Q | grep -E 'gcc|clang|make|cmake|python|rust|go|node|npm|yarn' | sort || echo "None identified";;
            "Network Tools") pacman -Q | grep -E 'nmap|wireshark|tcpdump|netcat|socat|openvpn|wireguard' | sort || echo "None identified";;
            "Reverse Engineering") pacman -Q | grep -E 'gdb|radare2|ghidra|binwalk|peda|pwndbg' | sort || echo "None identified";;
            "Web Testing") pacman -Q | grep -E 'burp|zap|sqlmap|nikto|gobuster|ffuf' | sort || echo "None identified";;
            "Exploitation Tools") pacman -Q | grep -E 'metasploit|exploitdb|searchsploit|msf' | sort || echo "None identified";;
            "Utils & System") pacman -Q | grep -E 'htop|btop|ranger|fzf|ripgrep|fd|jq|yq' | sort || echo "None identified";;
        esac
        echo "\`\`\`"
        echo ""
    done
} >> "${REPORT_FILE}"

# 5. Optional: AUR helper packages
if command -v yay &> /dev/null || command -v paru &> /dev/null; then
    print_status "Step 5: Identifying AUR packages..."
    {
        echo "## AUR Packages"
        echo ""
        echo "\`\`\`"
        pacman -Qqm 2>/dev/null | sort || echo "No AUR packages found"
        echo "\`\`\`"
        echo ""
    } >> "${REPORT_FILE}"
fi

# 6. Generate actionable recommendations
print_status "Step 6: Generating recommendations..."
{
    echo "## Actionable Recommendations"
    echo ""
    
    # Recommendation 1: Remove orphaned packages
    orphans=$(pacman -Qqtd)
    if [[ -n "${orphans}" ]]; then
        echo "### 🔴 Remove orphaned packages:"
        echo "\`sudo pacman -Rns \$(pacman -Qqtd)\`"
        echo ""
    fi
    
    # Recommendation 2: Review extra packages
    if [[ -f /tmp/extra-on-system.tmp ]] && [[ -s /tmp/extra-on-system.tmp ]]; then
        echo "### 🟡 Review extra packages (consider adding to manifest or removing):"
        cat /tmp/extra-on-system.tmp
        echo ""
    fi
    
    # Recommendation 3: Review dependencies
    deps=$(pacman -Qqdt)
    if [[ -n "${deps}" ]]; then
        echo "### 🟡 Review dependency packages (some may be removable if not needed):"
        echo "Use \`pacman -Qi <package>\` to check why each is installed."
        echo ""
    fi
    
    # Recommendation 4: Container-specific cleanup
    echo "### 🟢 Container package maintenance:"
    echo "Review container manifests in \`modules/container/profiles/*/manifest.txt\`"
    echo "Run \`./modules/container/scripts/container.sh prune\` to clean unused container data"
    echo ""
    
    # Recommendation 5: Cache cleanup
    echo "### 🟢 Clean package cache:"
    echo "\`sudo pacman -Sc\` (remove old versions)"
    echo "\`sudo pacman -Scc\` (remove all cached packages - use with caution)"
    echo ""
    
} >> "${REPORT_FILE}"

# Cleanup
rm -f /tmp/explicit-packages.tmp /tmp/missing-from-system.tmp /tmp/extra-on-system.tmp

print_success "Audit complete! Report saved to: ${REPORT_FILE}"
print_status "Review the report and follow the recommendations."
