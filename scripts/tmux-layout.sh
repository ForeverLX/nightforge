#!/usr/bin/env bash
set -euo pipefail

SESSION="${OFFSEC_TMUX_SESSION:-ops}"

ENGAGE="${OFFSEC_ENGAGE_DIR:-$HOME/engage}"
LOOT="${OFFSEC_LOOT_DIR:-$HOME/loot}"
NOTES="${OFFSEC_NOTES_DIR:-$HOME/notes}"
EXPLOIT="${OFFSEC_EXPLOITDEV_DIR:-$HOME/exploitdev}"


# If session exists, attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
  exec tmux attach -t "$SESSION"
fi

# Create session + windows (portable approach: cd via send-keys)
tmux new-session -d -s "$SESSION" -n engage
tmux send-keys -t "${SESSION}:engage" "cd \"$ENGAGE\"" C-m

tmux new-window -t "$SESSION" -n loot
tmux send-keys -t "${SESSION}:loot" "cd \"$LOOT\"" C-m

tmux new-window -t "$SESSION" -n notes
tmux send-keys -t "${SESSION}:notes" "cd \"$NOTES\"" C-m

tmux new-window -t "$SESSION" -n exploitdev
tmux send-keys -t "${SESSION}:exploitdev" "cd \"$EXPLOIT\"" C-m

tmux select-window -t "${SESSION}:engage"
exec tmux attach -t "$SESSION"
