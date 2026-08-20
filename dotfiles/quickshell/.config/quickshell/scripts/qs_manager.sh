#!/usr/bin/env bash
# Niri-compatible qs_manager - adapted from ilyamiro's Hyprland version

IPC_FILE="/tmp/qs_widget_state"
ACTION="$1"
TARGET="$2"
SUBTARGET="$3"

# Fast path: workspace switching
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    WORKSPACE_NUM="$ACTION"
    echo "close" > "$IPC_FILE"
    
    if [[ "$2" == "move" ]]; then
        # Move focused window to workspace
        niri msg action move-column-to-workspace "$WORKSPACE_NUM" >/dev/null 2>&1
    else
        niri msg action focus-workspace "$WORKSPACE_NUM" >/dev/null 2>&1
    fi
    exit 0
fi

# Toggle widgets
case "$ACTION" in
    toggle)
        echo "toggle:$TARGET:$SUBTARGET" > "$IPC_FILE"
        ;;
    close)
        echo "close" > "$IPC_FILE"
        ;;
    lock)
        niri msg action lock-screen >/dev/null 2>&1
        ;;
    *)
        echo "$ACTION:" > "$IPC_FILE"
        ;;
esac
