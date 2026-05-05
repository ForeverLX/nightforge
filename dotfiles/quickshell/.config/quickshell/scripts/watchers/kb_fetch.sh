#!/bin/bash
# Keyboard layout fetch script
# Outputs JSON: {"layout": "us"}

layout=""

# Try setxkbmap first
if command -v setxkbmap &>/dev/null; then
    layout=$(setxkbmap -query 2>/dev/null | grep 'layout:' | awk '{print $2}')
fi

# Fallback to localectl
if [ -z "$layout" ] && command -v localectl &>/dev/null; then
    layout=$(localectl status 2>/dev/null | grep "X11 Layout" | awk -F: '{print $2}' | xargs)
fi

# Fallback: check current keyboard group via xkb-switch or similar
if [ -z "$layout" ]; then
    layout="us"
fi

echo "{\"layout\": \"$layout\"}"
