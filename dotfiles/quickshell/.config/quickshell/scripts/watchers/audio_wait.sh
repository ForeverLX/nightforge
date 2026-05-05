#!/bin/bash
# Audio state wait script
# Blocks until audio state changes, outputs new state JSON
# Uses pactl subscribe to listen for sink change events

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
FETCH="$SCRIPT_DIR/audio_fetch.sh"

STATE_FILE="/tmp/qs_audio_state"
"$FETCH" > "$STATE_FILE"

pactl subscribe | grep --line-buffered "Event 'change' on sink #" | while read -r; do
    "$FETCH"
done
