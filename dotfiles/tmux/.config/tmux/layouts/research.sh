#!/bin/bash
# Research layout — vulnerability research and analysis
SESSION=$(tmux display-message -p '#S')

tmux new-window -t "$SESSION" -n "research"
tmux split-window -h -t "$SESSION:research" -p 40
tmux split-window -v -t "$SESSION:research.0" -p 40
tmux split-window -v -t "$SESSION:research.1" -p 40
tmux select-pane -t "$SESSION:research.0"
