#!/bin/bash
# qs_manager.sh — Quickshell IPC manager
# Adapted from ilyamiro's qs_manager.sh
# Handles zombie watchdog, IPC routing, workspace switching, and prep hooks.

MAIN_QML_PATH="$HOME/.config/quickshell/shell.qml"
TOGGLE_FILE="/tmp/quickshell-toggle"

# === FUNCTIONS ===

handle_network_prep() {
    local BT_PID_FILE="$HOME/.cache/bt_scan_pid"
    local BT_SCAN_LOG="$HOME/.cache/bt_scan.log"
    echo "" > "$BT_SCAN_LOG"
    { echo "scan on"; sleep infinity; } | stdbuf -oL bluetoothctl > "$BT_SCAN_LOG" 2>&1 &
    echo $! > "$BT_PID_FILE"
    nmcli device wifi rescan >/dev/null 2>&1 &
}

handle_wallpaper_prep() {
    local THUMB_DIR="$HOME/.cache/wallpaper_picker/thumbs"
    mkdir -p "$THUMB_DIR"
}

# === ZOMBIE WATCHDOG ===
if ! pgrep -f "quickshell.*shell\.qml" >/dev/null; then
    quickshell >/dev/null 2>&1 &
    disown
fi

# === PARSE ARGUMENTS ===
ACTION="${1:-}"
TARGET="${2:-}"

# === WORKSPACE SWITCHING (Niri) ===
if [[ "$ACTION" =~ ^[0-9]+$ ]]; then
    niri msg action focus-workspace "$ACTION"
    exit 0
fi

if [[ "$ACTION" == "move" && "$TARGET" =~ ^[0-9]+$ ]]; then
    niri msg action move-window-to-workspace "$TARGET"
    exit 0
fi

# === IPC ROUTING ===
case "$ACTION" in
    close)
        echo "close" > "$TOGGLE_FILE"
        ;;
    open:*)
        echo "$ACTION" > "$TOGGLE_FILE"
        ;;
    toggle:network)
        handle_network_prep
        echo "$ACTION" > "$TOGGLE_FILE"
        ;;
    toggle:wallpaper)
        handle_wallpaper_prep
        echo "$ACTION" > "$TOGGLE_FILE"
        ;;
    toggle:*)
        echo "$ACTION" > "$TOGGLE_FILE"
        ;;
    *)
        echo "Usage: $0 {close|open:TARGET|toggle:TARGET|NUMBER|move NUMBER}" >&2
        exit 1
        ;;
esac
