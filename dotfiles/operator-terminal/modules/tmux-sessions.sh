#!/bin/bash
# Tmux session awareness

if command -v tmux &>/dev/null; then
    SESSIONS=$(tmux list-sessions 2>/dev/null | wc -l)
    if (( SESSIONS > 0 )); then
        ACTIVE=$(tmux list-sessions 2>/dev/null | grep attached | wc -l)
        echo -e "\033[0;36m[◫] Tmux:\033[0m $SESSIONS sessions ($ACTIVE attached)"
    fi
fi
