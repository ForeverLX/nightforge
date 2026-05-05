#!/bin/bash
# Quickshell Widget IPC Router
# Usage: qs_manager.sh <widget_name|close|osd:type:label:value|launcher|status|exec:cmd>
#
# Features:
#   - Widget toggle/close via named pipes
#   - OSD display: osd:TYPE:LABEL:VALUE
#   - Launcher trigger
#   - Status query for debugging
#   - Race condition protection via flock

LOCK_FILE="/tmp/qs_manager.lock"
STATE_FILE="/tmp/qs_widget_state"
PIPE_FILE="/tmp/qs_widget_pipe"
STATUS_DIR="/tmp/qs_widget_status"

# Initialize
touch "$STATE_FILE"
mkdir -p "$STATUS_DIR"

# Acquire lock with flock to prevent race conditions
exec 200>"$LOCK_FILE"
flock -n 200 || {
    # If lock is held, queue via pipe if it exists
    if [ -p "$PIPE_FILE" ]; then
        echo "$*" > "$PIPE_FILE" 2>/dev/null
    fi
    exit 0
}

case "$1" in
    close)
        # Close the Quickshell overlay
        echo "close" > "$STATE_FILE"
        echo "{\"event\": \"close\", \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;

    launcher)
        # Launch the application launcher
        echo "launcher" > "$STATE_FILE"
        echo "{\"event\": \"launcher\", \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;

    status)
        # Output current widget state for debugging
        last_event="null"
        [ -f "$STATUS_DIR/last_event" ] && last_event=$(cat "$STATUS_DIR/last_event")
        widget_state="null"
        [ -f "$STATE_FILE" ] && widget_state=$(cat "$STATE_FILE")
        cat <<JSON
{
    "widget_state": $(echo "$widget_state" | jq -R . 2>/dev/null || echo "\"$widget_state\""),
    "last_event": $last_event,
    "lock_held": true,
    "ts": $(date +%s%N)
}
JSON
        ;;

    osd:*)
        # OSD display: osd:TYPE:LABEL:VALUE
        echo "$1" > "$STATE_FILE"
        echo "{\"event\": \"osd\", \"payload\": \"$1\", \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;

    exec:*)
        # Execute a custom command and write output to state
        cmd="${1#exec:}"
        output=$(eval "$cmd" 2>/dev/null)
        echo "$output" > "$STATE_FILE"
        echo "{\"event\": \"exec\", \"cmd\": \"$cmd\", \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;

    batch:*)
        # Process multiple commands: batch:cmd1|cmd2|cmd3
        # Each command is processed sequentially
        batch="${1#batch:}"
        IFS='|' read -ra cmds <<< "$batch"
        for cmd in "${cmds[@]}"; do
            case "$cmd" in
                close|launcher)
                    echo "$cmd" > "$STATE_FILE"
                    ;;
                osd:*)
                    echo "$cmd" > "$STATE_FILE"
                    ;;
                *)
                    echo "$cmd" > "$STATE_FILE"
                    ;;
            esac
            sleep 0.05  # Small delay between batched commands
        done
        echo "{\"event\": \"batch\", \"count\": ${#cmds[@]}, \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;

    *)
        # Widget toggle — write widget name to state file
        echo "$1" > "$STATE_FILE"
        echo "{\"event\": \"toggle\", \"widget\": \"$1\", \"ts\": $(date +%s%N)}" > "$STATUS_DIR/last_event" 2>/dev/null &
        ;;
esac

# Release lock (auto-released when subshell exits)
