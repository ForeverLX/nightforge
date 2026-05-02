#!/bin/bash
# Quick-edit engagement context
file="$HOME/.config/nightforge/engagement-context"
mkdir -p "$(dirname "$file")"
[[ -f "$file" ]] || echo "Recon" > "$file"
# Open in preferred editor
if command -v obsidian &>/dev/null; then
  obsidian "$file"
elif command -v nano &>/dev/null; then
  nano "$file"
else
  echo "No editor found"
fi
