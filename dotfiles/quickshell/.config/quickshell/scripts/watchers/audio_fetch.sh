#!/bin/bash
# Audio state fetch script
# Outputs: {"volume": 75, "mute": false, "source": "wpctl"}

vol=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null)
if [ -n "$vol" ]; then
    mute=$(echo "$vol" | grep -q "MUTED" && echo "true" || echo "false")
    pct=$(echo "$vol" | grep -oP '[\d.]+' | head -1 | awk '{print int($1*100)}')
    echo "{\"volume\": $pct, \"mute\": $mute, \"source\": \"wpctl\"}"
else
    echo "{\"volume\": 0, \"mute\": true, \"source\": \"unknown\"}"
fi
