#!/usr/bin/env bash
# List available PipeWire sinks with descriptions
# Output: ">name|desc" for active, "name|desc" for others

DEFAULT=$(pactl get-default-sink 2>/dev/null)
pactl list sinks short 2>/dev/null | while read id name rest; do
    [ -z "$name" ] && continue
    desc=$(pactl list sinks 2>/dev/null | awk -v n="$name" '/Name:/ {f=($2==n)} f && /Description:/ {sub(/.*: /,""); print; exit}')
    [ -z "$desc" ] && desc="$name"
    if [ "$name" = "$DEFAULT" ]; then
        echo ">$name|$desc"
    else
        echo "$name|$desc"
    fi
done
