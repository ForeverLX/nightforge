#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <engagement-name>"
  exit 1
fi

NAME="$1"
SESSION="eng-${NAME}"

ENGAGE_DIR="$HOME/engage/${NAME}"
LOOT_DIR="$HOME/loot/${NAME}"
NOTES_DIR="$HOME/notes/${NAME}"
EXPLOIT_DIR="$HOME/exploitdev/${NAME}"

mkdir -p "$ENGAGE_DIR" "$LOOT_DIR" "$NOTES_DIR" "$EXPLOIT_DIR"
chmod 700 "$HOME/loot" || true
chmod 700 "$LOOT_DIR" || true

# Attach if it already exists
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Create session + recon window
tmux new-session -d -s "$SESSION" -n recon
tmux send-keys -t "${SESSION}:recon" "cd \"$ENGAGE_DIR\"" C-m

# Split recon into two panes. After this, panes are reliably 0 and 1.
tmux split-window -h -t "${SESSION}:recon"
tmux send-keys -t "${SESSION}:recon.0" "cd \"$ENGAGE_DIR\"" C-m
tmux send-keys -t "${SESSION}:recon.1" "cd \"$ENGAGE_DIR\"" C-m

# Create other windows (independent of pane state)
tmux new-window -t "$SESSION" -n loot
tmux send-keys -t "${SESSION}:loot" "cd \"$LOOT_DIR\"" C-m

tmux new-window -t "$SESSION" -n notes
tmux send-keys -t "${SESSION}:notes" "cd \"$NOTES_DIR\"" C-m

tmux new-window -t "$SESSION" -n exploitdev
tmux send-keys -t "${SESSION}:exploitdev" "cd \"$EXPLOIT_DIR\"" C-m

tmux new-window -t "$SESSION" -n server
tmux send-keys -t "${SESSION}:server" "cd \"$ENGAGE_DIR\"" C-m

tmux select-window -t "${SESSION}:recon"
exec tmux attach -t "$SESSION"
