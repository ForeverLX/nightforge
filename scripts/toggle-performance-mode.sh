#!/bin/bash
# Toggle performance mode
file="$HOME/.config/nightforge/performance-mode"
mkdir -p "$(dirname "$file")"
current=$(cat "$file" 2>/dev/null || echo "high")
if [ "$current" = "high" ]; then
    echo "low" > "$file"
    notify-send "Performance Mode" "Switched to Low" --icon=battery-low
else
    echo "high" > "$file"
    notify-send "Performance Mode" "Switched to High" --icon=cpu
fi
