#!/bin/bash
# Blocks until battery capacity changes
# Use inotifywait on sysfs if available, otherwise poll
BAT_PATH=$(find /sys/class/power_supply/BAT* -name capacity 2>/dev/null | head -1)
if [ -n "$BAT_PATH" ] && command -v inotifywait >/dev/null 2>&1; then
    inotifywait -e modify "$BAT_PATH" 2>/dev/null
else
    # Fallback: poll every 30s
    sleep 30
fi
