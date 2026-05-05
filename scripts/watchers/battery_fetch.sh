#!/bin/bash
# Output: {"icon":"BAT_ICON","pct":NUM,"level":"LEVEL"}

pct=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
if [ -n "$pct" ]; then
    status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)
    if [ "$status" = "Charging" ]; then icon="󰂄"
    elif [ "$pct" -lt 15 ]; then icon="󰁺"
    elif [ "$pct" -lt 30 ]; then icon="󰁼"
    elif [ "$pct" -lt 60 ]; then icon="󰁾"
    elif [ "$pct" -lt 85 ]; then icon="󰂀"
    else icon="󰁹"; fi
    echo "{\"icon\":\"$icon\",\"pct\":$pct,\"level\":\"$status\"}"
    exit 0
fi

# Fallback: hidpp peripherals
for d in /sys/class/power_supply/hidpp_*/; do
    [ -d "$d" ] || continue
    name=$(cat "${d}model_name" 2>/dev/null || echo "Peripheral")
    pct=$(cat "${d}capacity" 2>/dev/null)
    if [ -n "$pct" ]; then
        [ "$pct" -lt 30 ] && icon="󰥙" || icon="󰥘"
        echo "{\"icon\":\"$icon\",\"pct\":$pct,\"level\":\"$name\"}"
        exit 0
    fi
done

echo '{"icon":"󰂎","pct":0,"level":"N/A"}'
