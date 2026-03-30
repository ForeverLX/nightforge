#!/bin/bash
# tmux-picker.sh — fuzzel layout picker → launch selected tmux layout
selected=$(ls ~/.config/tmux/layouts/*.conf | xargs -I{} basename {} .conf | \
    fuzzel --dmenu --prompt="layout: " --lines=9 --width=30)
[[ -n "$selected" ]] && exec ghostty --title=tmux-picker \
    -e ~/Github/nightforge/scripts/tmux-session.sh "$selected"
