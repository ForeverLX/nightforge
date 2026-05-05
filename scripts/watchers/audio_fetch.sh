#!/bin/bash
# Output: {"icon":"VOLUME_ICON","vol":NUM,"mute":true|false}

info=$(wpctl get-volume @DEFAULT_SINK@ 2>/dev/null)
if echo "$info" | grep -q "MUTED"; then
    vol=0
    mute=true
    icon="󰝟"
else
    vol=$(echo "$info" | grep -oP '[\d.]+' | head -1)
    vol=$(awk "BEGIN {printf \"%d\", $vol * 100}")
    mute=false
    if [ "$vol" -eq 0 ]; then icon="󰝟"
    elif [ "$vol" -lt 34 ]; then icon="󰕿"
    elif [ "$vol" -lt 67 ]; then icon="󰖀"
    else icon="󰕾"; fi
fi

echo "{\"icon\":\"$icon\",\"vol\":$vol,\"mute\":$mute}"
