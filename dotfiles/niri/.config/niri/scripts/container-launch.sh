#!/bin/bash
# Container Launch Script
# Focus existing container terminal or spawn new one

set -euo pipefail

PROFILE="${1:-}"

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile>"
    echo "Profiles: web, ad, re, toolbox"
    exit 1
fi

# Container script path
CONTAINER_SCRIPT="$HOME/Github/offsec-workstation/modules/container/scripts/container.sh"

# Check if container terminal is already running
# This is a placeholder - we'll need to implement proper window detection
# For now, just spawn a new terminal with container

case "$PROFILE" in
    web|ad|re|toolbox)
        # Launch container in terminal
        ghostty -e bash -c "$CONTAINER_SCRIPT run $PROFILE"
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        exit 1
        ;;
esac
