#!/usr/bin/env bash

# ============================================================================
# 1. ZOMBIE PREVENTION
# Kills any older instances of this script. When Quickshell reloads, 
# it can leave the old listener pipelines running in the background infinitely.
# ============================================================================
for pid in $(pgrep -f "quickshell/workspaces.sh"); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done

# Cleanly kill immediate children when the script exits normally
cleanup() {
    pkill -P $$ 2>/dev/null
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
BT_PID_FILE="$HOME/.cache/bt_scan_pid"

if [ -f "$BT_PID_FILE" ]; then
    kill $(cat "$BT_PID_FILE") 2>/dev/null
    rm -f "$BT_PID_FILE"
fi

(timeout 2 bluetoothctl scan off > /dev/null 2>&1) &

# Configuration: Parse from settings.json dynamically, fallback to 8
SETTINGS_FILE="$HOME/.config/niri/settings.json"
SEQ_END=$(jq -r '.workspaceCount // 8' "$SETTINGS_FILE" 2>/dev/null)
if ! [[ "$SEQ_END" =~ ^[0-9]+$ ]]; then
    SEQ_END=8
fi

print_workspaces() {
    local spaces active_windows active_id output

    spaces=$(timeout 2 niri msg -j workspaces 2>/dev/null)
    active_windows=$(timeout 2 niri msg -j windows 2>/dev/null)

    if [ -z "$spaces" ]; then return; fi

    active_id=$(echo "$spaces" | jq -r '.[] | select(.is-focused) | .id' 2>/dev/null | head -1)

    output=$(echo "$spaces" | jq --unbuffered \
        --argjson active_id "${active_id:-0}" \
        --argjson windows "$active_windows" \
        --arg end "$SEQ_END" -c '
        # Count windows per workspace
        ($windows | group_by(.workspace-id) | map({key: .[0]."workspace-id", value: length}) | from_entries) as $win_count
        |
        # Get last window title per workspace
        ($windows | map({wid: ."workspace-id", title: .title}) | group_by(.wid) | map({key: .[0].wid, value: .[-1].title}) | from_entries) as $win_title
        |
        # Build workspace entries
        [ .[] | {
            id: .id,
            state: (
                if .id == $active_id then "active"
                elif (($win_count[.id | tostring] // 0) > 0) then "occupied"
                else "empty"
                end
            ),
            tooltip: ($win_title[.id | tostring] // "Empty")
        } ]
        |
        # Pad up to SEQ_END with empty slots
        + [range([ .[-1].id // 0 ] | . + 1; ($end | tonumber) + 1) | {id: ., state: "empty", tooltip: "Empty"}]
    ' 2>/dev/null)

    if [ -z "$output" ]; then return; fi

    echo "$output" > /tmp/qs_workspaces.tmp
    mv /tmp/qs_workspaces.tmp /tmp/qs_workspaces.json
}

print_workspaces

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Niri IPC events wrapped in an infinite loop
# ============================================================================
while true; do
    niri msg -j event-stream 2>/dev/null | while read -r line; do
        case "$line" in
            *Workspaces*|*Windows*|*WorkspaceActivated*|*FocusWindow*)
                while read -t 0.05 -r extra_line; do
                    continue
                done
                print_workspaces
                ;;
        esac
    done
    sleep 1
done