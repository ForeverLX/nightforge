#!/bin/bash
# Install git hooks to prevent AI agent co-author attribution
# Run this script after cloning the repo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../.git/hooks"

mkdir -p "$HOOKS_DIR"
ln -sf "$SCRIPT_DIR/commit-msg" "$HOOKS_DIR/commit-msg"
chmod +x "$SCRIPT_DIR/commit-msg"

echo "Hooks installed. Edit scripts/hooks/blocklist to manage blocked agents."
