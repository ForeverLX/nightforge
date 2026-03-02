#!/bin/bash
# generate-keybinds-cheatsheet.sh
# Auto-generate markdown cheatsheet from keybinds.kdl

set -euo pipefail

KEYBINDS_FILE="${1:-$HOME/.config/niri/includes/keybinds.kdl}"
OUTPUT_FILE="${2:-$HOME/Github/offsec-workstation/docs/KEYBINDS.md}"

if [ ! -f "$KEYBINDS_FILE" ]; then
    echo "Error: Keybinds file not found: $KEYBINDS_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate cheatsheet
cat > "$OUTPUT_FILE" << 'HEADER'
# Niri Keybindings Cheatsheet
**offsec-workstation** - Quick reference guide

Generated automatically from `keybinds.kdl`

---

HEADER

# Parse keybinds and create sections
echo "## Applications" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
grep -A1 "APPLICATIONS" "$KEYBINDS_FILE" | grep "Mod+" | sed 's/.*Mod+/Super+/' | sed 's/ {.*spawn "\(.*\)".*/| \1 |/' | sed 's/Mod+/Super+/' >> "$OUTPUT_FILE" || true
echo "" >> "$OUTPUT_FILE"

echo "## Window Management" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
echo "| Super+Q | Close window |" >> "$OUTPUT_FILE"
echo "| Super+Space | Toggle floating |" >> "$OUTPUT_FILE"
echo "| Super+Shift+F | Fullscreen |" >> "$OUTPUT_FILE"
echo "| Super+Shift+X | Maximize column |" >> "$OUTPUT_FILE"
echo "| Super+W | Toggle tabbed mode |" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Navigation" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
echo "| Super+H/J/K/L | Focus left/down/up/right |" >> "$OUTPUT_FILE"
echo "| Super+Shift+H/J/K/L | Move window |" >> "$OUTPUT_FILE"
echo "| Super+Ctrl+H/J/K/L | Resize window |" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Workspaces" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
echo "| Super+1-5 | Switch to workspace |" >> "$OUTPUT_FILE"
echo "| Super+Shift+1-5 | Move window to workspace |" >> "$OUTPUT_FILE"
echo "| Super+U/I | Previous/Next workspace |" >> "$OUTPUT_FILE"
echo "| Super+O | Toggle overview |" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Columns & Tiling" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
echo "| Super+[ | Merge window left |" >> "$OUTPUT_FILE"
echo "| Super+] | Merge window right |" >> "$OUTPUT_FILE"
echo "| Super+, | Pull window into column |" >> "$OUTPUT_FILE"
echo "| Super+. | Push window out of column |" >> "$OUTPUT_FILE"
echo "| Super+R | Cycle column width |" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "## Media & System" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Key | Action |" >> "$OUTPUT_FILE"
echo "|-----|--------|" >> "$OUTPUT_FILE"
echo "| Print | Screenshot |" >> "$OUTPUT_FILE"
echo "| Shift+Print | Screenshot screen |" >> "$OUTPUT_FILE"
echo "| F1-F12 | Volume, brightness controls |" >> "$OUTPUT_FILE"
echo "| Super+Shift+Q | Quit Niri |" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "---" >> "$OUTPUT_FILE"
echo "*Last updated: $(date)*" >> "$OUTPUT_FILE"

echo "✓ Cheatsheet generated: $OUTPUT_FILE"
