#!/usr/bin/env bash
set -euo pipefail

SESSION="${NIGHTOWL_TMUX_SESSION:-nightowl}"

CODE_DIR="${NIGHTOWL_CODE_DIR:-$HOME/projects/nightowl}"
RUNS_DIR="${NIGHTOWL_RUNS_DIR:-$HOME/engage/nightowl/runs}"
NOTES_DIR="${NIGHTOWL_NOTES_DIR:-$HOME/notes}"
EXPLOIT_DIR="${OFFSEC_EXPLOITDEV_DIR:-$HOME/exploitdev}"

mkdir -p "$RUNS_DIR"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# code window (2 panes)
tmux new-session -d -s "$SESSION" -n code
tmux send-keys -t "${SESSION}:code" "cd \"$CODE_DIR\"" C-m
tmux split-window -h -t "${SESSION}:code"
tmux send-keys -t "${SESSION}:code.0" "cd \"$CODE_DIR\"" C-m
tmux send-keys -t "${SESSION}:code.1" "cd \"$CODE_DIR\"" C-m

# runs window
tmux new-window -t "$SESSION" -n runs
tmux send-keys -t "${SESSION}:runs" "cd \"$RUNS_DIR\"" C-m

# notes window
tmux new-window -t "$SESSION" -n notes
tmux send-keys -t "${SESSION}:notes" "cd \"$NOTES_DIR\"" C-m

# exploitdev window
tmux new-window -t "$SESSION" -n exploitdev
tmux send-keys -t "${SESSION}:exploitdev" "cd \"$EXPLOIT_DIR\"" C-m

tmux select-window -t "${SESSION}:code"
exec tmux attach -t "$SESSION"
