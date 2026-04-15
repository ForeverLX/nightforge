#!/bin/bash
# Engagement layout — active red team work
SESSION=$(tmux display-message -p '#S')

tmux new-window -t "$SESSION" -n "engagement"
tmux split-window -h -t "$SESSION:engagement" -p 40
tmux split-window -v -t "$SESSION:engagement.0" -p 35
tmux split-window -v -t "$SESSION:engagement.1" -p 40
tmux select-pane -t "$SESSION:engagement.0"
