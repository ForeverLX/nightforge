#!/usr/bin/env bash

# Mission Control - Offsec Workstation
# Aesthetics: Catppuccin Mocha

VPN_STATUS=$(ip addr show tun0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "No VPN")
TARGET=$(cat "$HOME/engage/current/target.txt" 2>/dev/null || echo "None")

OPTIONS="󰆍 New Engagement\n󰒲 Attach Existing Session\n󰒓 Set Target IP\n󰀦 Clear Current Context"

# Launch Fuzzel
CHOICE=$(echo -e "$OPTIONS" | fuzzel --dmenu \
    --prompt="󰘳 [$VPN_STATUS | Target: $TARGET] >> " \
    --font="JetBrainsMono Nerd Font:size=12" \
    --text-color="cdd6f4ff" \
    --background-color="1e1e2eff" \
    --match-color="f38ba8ff" \
    --selection-color="313244ff" \
    --selection-text-color="cdd6f4ff" \
    --border-color="b4befeff" \
    --border-width=2 \
    --border-radius=8 \
    --width=45)

[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
    *"New Engagement"*)
        NAME=$(echo "" | fuzzel --dmenu --prompt="󰚌 Engagement Name: ")
        [[ -z "$NAME" ]] && exit 0
        TYPE=$(echo -e "ad\nre\nweb\ngeneric" | fuzzel --dmenu --prompt="󰆟 Type: ")
        ghostty -e "$HOME/Github/offsec-workstation/scripts/tmux-engage.sh" "$NAME" "$TYPE"
        ;;
    *"Attach Existing Session"*)
        SESS=$(tmux ls -F '#S' | fuzzel --dmenu --prompt="󰓦 Select Session: ")
        [[ -z "$SESS" ]] && exit 0
        ghostty -e "tmux attach -t $SESS"
        ;;
    *"Set Target IP"*)
        IP=$(echo "" | fuzzel --dmenu --prompt="󰓾 Target IP: ")
        if [[ ! -z "$IP" ]]; then
            mkdir -p "$HOME/engage/current"
            echo "$IP" > "$HOME/engage/current/target.txt"
            notify-send "Mission Control" "Target set to $IP"
        fi
        ;;
    *"Clear Current Context"*)
        rm -rf "$HOME/engage/current"
        notify-send "Mission Control" "Operational context cleared."
        ;;
esac
