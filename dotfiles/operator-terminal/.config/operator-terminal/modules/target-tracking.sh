#!/bin/bash
# Target tracking for active engagements

if [[ -f "$HOME/engage/current/.target" ]]; then
    TARGET=$(cat "$HOME/engage/current/.target")
    echo -e "\033[0;31m[🎯] Target:\033[0m $TARGET"
fi
