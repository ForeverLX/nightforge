#!/bin/bash
# Simple screen record toggle using wf-recorder
RECORDING_PID="/tmp/qs_screen_record.pid"
RECORDING_FILE="$HOME/Videos/Screen Recordings/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"

mkdir -p "$(dirname "$RECORDING_FILE")"

if [ -f "$RECORDING_PID" ] && kill -0 "$(cat "$RECORDING_PID")" 2>/dev/null; then
    # Stop recording
    kill "$(cat "$RECORDING_PID")" 2>/dev/null
    rm -f "$RECORDING_PID"
    notify-send "Screen Recording" "Saved to $RECORDING_FILE"
else
    # Start recording
    wf-recorder -f "$RECORDING_FILE" &
    echo $! > "$RECORDING_PID"
    notify-send "Screen Recording" "Recording started"
fi
