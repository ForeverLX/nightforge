#!/bin/bash
# Daily operator layout — NightForge work session
SESSION=$(tmux display-message -p '#S')

tmux new-window -t "$SESSION" -n "daily"
tmux split-window -h -t "$SESSION:daily" -p 35
tmux split-window -v -t "$SESSION:daily.1" -p 40
tmux select-pane -t "$SESSION:daily.0"
