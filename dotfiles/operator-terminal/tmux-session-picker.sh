#!/bin/bash
# Tmux session picker

SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null)

if [[ -z "$SESSIONS" ]]; then
    # No sessions, create default
    tmux new-session -s main
else
    # Pick session with fzf or first available
    if command -v fzf &>/dev/null; then
        SESSION=$(echo "$SESSIONS" | fzf --prompt="Select tmux session: ")
        [[ -n "$SESSION" ]] && tmux attach -t "$SESSION"
    else
        tmux attach
    fi
fi
