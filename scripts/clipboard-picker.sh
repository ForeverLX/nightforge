#!/bin/bash
# Clipboard picker — uses fuzzel + cliphist
set -euo pipefail

if ! command -v cliphist &>/dev/null; then
    echo "cliphist not found" >&2
    exit 1
fi

cliphist list | fuzzel --dmenu --prompt "clipboard: " | cliphist decode | wl-copy
