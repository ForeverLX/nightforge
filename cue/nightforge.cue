package niri

// NightForge Niri configuration data (CUE migration).
// Transcribed from dotfiles/niri/.config/niri/{config.kdl,includes/keybinds.kdl,
// includes/window-rules.kdl} — semantics must stay in sync with the KDL source;
// fidelity-check.sh verifies parity automatically.

config: #Config & {
	spawnAtStartup: [
		{argv: ["awww-daemon"], comment: "Wallpaper daemon"},
		{argv: ["bash", "-c", "quickshell &"], comment: "Quickshell overlay"},
		{argv: ["bash", "-c", "sleep 1 && quickshell -p $HOME/.config/quickshell/TopBar.qml &"], comment: "Quickshell TopBar"},
		{argv: ["bash", "-c", "sleep 2 && $HOME/.local/bin/matugen-sync.sh $HOME/Pictures/wallpapers/current.jpg"], comment: "Matugen sync"},
		{argv: ["systemctl", "--user", "start", "podman-restart.service"], comment: "Podman services"},
		{argv: ["systemctl", "--user", "enable", "--now", "wallpaper-rotate.timer"], comment: "Wallpaper rotation"},
		{argv: ["bash", "-c", "sleep 2 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri"], comment: "Screensharing env"},
		{argv: ["systemctl", "--user", "start", "mpd.service"], comment: "MPD user service"},
	]

	binds: [
		// HELP
		{combo: "Mod+Shift+Slash", action: {kind: "builtin", name: "show-hotkey-overlay"}},
		{combo: "Mod+Slash", action: {kind: "spawn", argv: ["sh", "-c", "~/.config/niri/scripts/keybind-cheatsheet.sh"]}},
		// APPLICATIONS
		{combo: "Mod+Return", action: {kind: "spawn", argv: ["ghostty"]}},
		{combo: "Mod+D", action: {kind: "spawn", argv: ["fuzzel"]}},
		{combo: "Mod+B", action: {kind: "spawn", argv: ["sh", "-c", "~/.config/niri/scripts/focus-or-spawn.sh firefox"]}},
		{combo: "Mod+F", action: {kind: "spawn", argv: ["ghostty", "-e", "yazi"]}},
		// QUICKSHELL WIDGET TOGGLES
		{combo: "Mod+Shift+C", action: {kind: "spawn", argv: ["sh", "-c", "echo settings > /tmp/qs_widget_state"]}},
		{combo: "Mod+M", action: {kind: "spawn", argv: ["sh", "-c", "echo music > /tmp/qs_widget_state"]}},
		{combo: "Mod+Shift+N", action: {kind: "spawn", argv: ["sh", "-c", "echo network > /tmp/qs_widget_state"]}},
		{combo: "Mod+Shift+W", action: {kind: "spawn", argv: ["sh", "-c", "echo wallpaper > /tmp/qs_widget_state"]}},
		{combo: "Mod+Shift+M", action: {kind: "spawn", argv: ["sh", "-c", "echo monitor > /tmp/qs_widget_state"]}},
		{combo: "Mod+Comma", action: {kind: "spawn", argv: ["sh", "-c", "echo settings > /tmp/qs_widget_state"]}},
		{combo: "Mod+Shift+V", action: {kind: "spawn", argv: ["sh", "-c", "echo clipboard > /tmp/qs_widget_state"]}},
		{combo: "Mod+Shift+D", action: {kind: "spawn", argv: ["sh", "-c", "echo dashboard > /tmp/qs_widget_state"]}},
		{combo: "Mod+Escape", action: {kind: "spawn", argv: ["sh", "-c", "echo close > /tmp/qs_widget_state"]}},
		// SCREENSHOTS
		{combo: "Print", action: {kind: "builtin", name: "screenshot"}},
		{combo: "Alt+Print", action: {kind: "builtin", name: "screenshot-window"}},
		{combo: "Mod+S", action: {kind: "spawn", argv: ["sh", "-c", "~/.config/niri/scripts/screenshot.sh area-clipboard"]}},
		{combo: "Mod+Shift+R", action: {kind: "spawn", argv: ["sh", "-c", "~/.config/niri/scripts/screen-record.sh"]}},
		// SWAYOSD OVERLAYS
		{combo: "XF86AudioRaiseVolume", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--output-volume", "raise"]}},
		{combo: "XF86AudioLowerVolume", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--output-volume", "lower"]}},
		{combo: "XF86AudioMute", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--output-volume", "toggle"]}},
		{combo: "XF86AudioMicMute", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--input-volume", "toggle"]}},
		{combo: "XF86MonBrightnessUp", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--brightness", "raise"]}},
		{combo: "XF86MonBrightnessDown", allowWhenLocked: true, action: {kind: "spawn", argv: ["swayosd-client", "--brightness", "lower"]}},
		{combo: "XF86AudioPlay", allowWhenLocked: true, action: {kind: "spawn", argv: ["playerctl", "play-pause"]}},
		{combo: "XF86AudioPrev", allowWhenLocked: true, action: {kind: "spawn", argv: ["playerctl", "previous"]}},
		{combo: "XF86AudioNext", allowWhenLocked: true, action: {kind: "spawn", argv: ["playerctl", "next"]}},
		// CLIPBOARD / NOTIFICATIONS
		{combo: "Mod+V", action: {kind: "spawn", argv: ["sh", "-c", "~/.local/bin/clipboard-picker.sh"]}},
		// POWER / LOCK
		{combo: "Mod+Alt+L", action: {kind: "spawn", argv: ["sh", "-c", "~/.config/quickshell/scripts/lock-screen.sh"]}},
		{combo: "Mod+Alt+Q", action: {kind: "builtin", name: "quit"}},
		{combo: "Mod+Shift+E", action: {kind: "spawn", argv: ["bash", "$HOME/Github/nightforge/scripts/engagement-edit.sh"]}},
		// WINDOW MANAGEMENT
		{combo: "Mod+Q", action: {kind: "builtin", name: "close-window"}},
		{combo: "Mod+Space", repeat: false, hotkeyOverlayTitle: "Toggle overview", action: {kind: "builtin", name: "toggle-overview"}},
		{combo: "Mod+Shift+Space", action: {kind: "builtin", name: "toggle-window-floating"}},
		{combo: "Mod+Shift+X", action: {kind: "builtin", name: "maximize-column"}},
		{combo: "Mod+W", action: {kind: "builtin", name: "toggle-column-tabbed-display"}},
		{combo: "Mod+G", action: {kind: "builtin", name: "toggle-window-floating"}},
		{combo: "Mod+C", action: {kind: "builtin", name: "center-column"}},
		{combo: "Mod+Backslash", action: {kind: "spawn", argv: ["bash", "-c", "~/.config/quickshell/scripts/niri_tweaks/tweaks window-details"]}},
		{combo: "Mod+Alt+C", hotkeyOverlayTitle: "Center Window", action: {kind: "builtin", name: "center-window"}},
		// SMART NAVIGATION
		{combo: "Mod+H", action: {kind: "builtin", name: "focus-column-left"}},
		{combo: "Mod+L", action: {kind: "builtin", name: "focus-column-right"}},
		{combo: "Mod+J", action: {kind: "builtin", name: "focus-window-or-workspace-down"}},
		{combo: "Mod+K", action: {kind: "builtin", name: "focus-window-or-workspace-up"}},
		{combo: "Mod+U", action: {kind: "builtin", name: "focus-workspace-down"}},
		{combo: "Mod+I", action: {kind: "builtin", name: "focus-workspace-up"}},
		// WINDOW MOVEMENT
		{combo: "Mod+Shift+H", action: {kind: "builtin", name: "move-column-left"}},
		{combo: "Mod+Shift+L", action: {kind: "builtin", name: "move-column-right"}},
		{combo: "Mod+Shift+J", action: {kind: "builtin", name: "move-window-down-or-to-workspace-down"}},
		{combo: "Mod+Shift+K", action: {kind: "builtin", name: "move-window-up-or-to-workspace-up"}},
		// MULTI-MONITOR
		{combo: "Mod+Shift+Left", action: {kind: "builtin", name: "move-column-to-monitor-left"}},
		{combo: "Mod+Shift+Right", action: {kind: "builtin", name: "move-column-to-monitor-right"}},
		{combo: "Mod+Alt+Left", action: {kind: "builtin", name: "focus-monitor-left"}},
		{combo: "Mod+Alt+Right", action: {kind: "builtin", name: "focus-monitor-right"}},
		// COLUMN MANAGEMENT
		{combo: "Mod+BracketLeft", action: {kind: "builtin", name: "consume-or-expel-window-left"}},
		{combo: "Mod+BracketRight", action: {kind: "builtin", name: "consume-or-expel-window-right"}},
		{combo: "Mod+Period", action: {kind: "builtin", name: "expel-window-from-column"}},
		{combo: "Mod+Tab", action: {kind: "builtin", name: "focus-workspace-previous"}},
		// AUDIO
		{combo: "Mod+A", action: {kind: "spawn", argv: ["sh", "-c", "~/.local/bin/audio-switch.sh toggle"]}},
		// WORKSPACES
		{combo: "Mod+1", action: {kind: "builtin", name: "focus-workspace", arg: "1"}},
		{combo: "Mod+2", action: {kind: "builtin", name: "focus-workspace", arg: "2"}},
		{combo: "Mod+3", action: {kind: "builtin", name: "focus-workspace", arg: "3"}},
		{combo: "Mod+4", action: {kind: "builtin", name: "focus-workspace", arg: "4"}},
		{combo: "Mod+5", action: {kind: "builtin", name: "focus-workspace", arg: "5"}},
		{combo: "Mod+6", action: {kind: "builtin", name: "focus-workspace", arg: "6"}},
		{combo: "Mod+7", action: {kind: "builtin", name: "focus-workspace", arg: "7"}},
		{combo: "Mod+8", action: {kind: "builtin", name: "focus-workspace", arg: "8"}},
		{combo: "Mod+9", action: {kind: "builtin", name: "focus-workspace", arg: "9"}},
		{combo: "Mod+Shift+1", action: {kind: "builtin", name: "move-column-to-workspace", arg: "1"}},
		{combo: "Mod+Shift+2", action: {kind: "builtin", name: "move-column-to-workspace", arg: "2"}},
		{combo: "Mod+Shift+3", action: {kind: "builtin", name: "move-column-to-workspace", arg: "3"}},
		{combo: "Mod+Shift+4", action: {kind: "builtin", name: "move-column-to-workspace", arg: "4"}},
		{combo: "Mod+Shift+5", action: {kind: "builtin", name: "move-column-to-workspace", arg: "5"}},
		{combo: "Mod+Shift+6", action: {kind: "builtin", name: "move-column-to-workspace", arg: "6"}},
		{combo: "Mod+Shift+7", action: {kind: "builtin", name: "move-column-to-workspace", arg: "7"}},
		{combo: "Mod+Shift+8", action: {kind: "builtin", name: "move-column-to-workspace", arg: "8"}},
		{combo: "Mod+Shift+9", action: {kind: "builtin", name: "move-column-to-workspace", arg: "9"}},
		// RESIZING
		{combo: "Mod+Ctrl+H", action: {kind: "builtin", name: "set-window-width", arg: "-10%"}},
		{combo: "Mod+Ctrl+L", action: {kind: "builtin", name: "set-window-width", arg: "+10%"}},
		{combo: "Mod+Ctrl+J", action: {kind: "builtin", name: "set-window-height", arg: "-10%"}},
		{combo: "Mod+Ctrl+K", action: {kind: "builtin", name: "set-window-height", arg: "+10%"}},
		{combo: "Mod+R", action: {kind: "builtin", name: "switch-preset-column-width"}},
		// OBSIDIAN
		{combo: "Mod+Alt+D", action: {kind: "spawn", argv: ["obsidian", "obsidian://daily"]}},
		{combo: "Mod+Shift+O", action: {kind: "spawn", argv: ["obsidian", "obsidian://search"]}},
		{combo: "Mod+O", action: {kind: "spawn", argv: ["obsidian", "obsidian://open?vault=azrael-vault"]}},
		// SYSTEM
		{combo: "Mod+Shift+P", action: {kind: "spawn", argv: ["bash", "$HOME/Github/nightforge/scripts/toggle-performance-mode.sh"]}},
		// WALLPAPER ROTATION
		{combo: "Mod+Alt+R", action: {kind: "spawn", argv: ["bash", "-c", "~/.local/bin/wallpaper-rotate.sh --notify && ~/.local/bin/matugen-sync.sh $(cat ~/.cache/current_wallpaper)"]}},
		// OPERATOR SHORTCUTS
		{combo: "Mod+Shift+G", action: {kind: "spawn", argv: ["ghostty", "-e", "cat ~/.config/nightforge/engagement-context 2>/dev/null || echo 'No active engagement'"]}},
		{combo: "Mod+Shift+T", action: {kind: "spawn", argv: ["ghostty", "-e", "podman ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"]}},
	]

	windowRules: [
		// GLOBAL APPEARANCE
		{geometryCornerRadius: 8, clipToGeometry: true, comment: "Global appearance"},
		// POPUP / MODAL FLOATING
		{title: "^.*Preferences$", openFloating: true},
		{title: "^.*Settings$", openFloating: true},
		{title: "^.*Save As$", openFloating: true},
		// QUICKSHELL POPUPS
		{appId: "^qs-", openFloating: true, comment: "Quickshell overlay windows"},
		{appId: "^nightforge", openFloating: true},
		{title: "^NightForge Music$", openFloating: true, defaultColumnWidth: {proportion: 0.5}, maxWidth: 700, maxHeight: 650},
		// BROWSERS
		{appId: "^waterfox$", opacity: 0.92, defaultColumnWidth: {proportion: 0.66667}},
		{appId: "^waterfox$", title: "^.*Picture-in-Picture$", openFloating: true, maxWidth: 400, maxHeight: 300},
		{title: "^.* — Waterfox$", openFloating: true},
		{appId: "firefox$", opacity: 0.92, defaultColumnWidth: {proportion: 0.66667}},
		{appId: "firefox$", title: "^.*Picture-in-Picture$", openFloating: true, maxWidth: 400, maxHeight: 300},
		// TERMINALS
		{appId: "^com\\.mitchellh\\.ghostty$", opacity: 0.65, defaultColumnWidth: {proportion: 0.5}},
		{appId: "^com\\.mitchellh\\.ghostty$", title: "^tmux-picker$", openFullscreen: true, opacity: 0.65},
		{title: "^btop-monitor$", openFloating: true, defaultColumnWidth: {fixed: 960}, defaultWindowHeight: {fixed: 700}},
		// NOTES
		{appId: "obsidian$", opacity: 0.90, defaultColumnWidth: {proportion: 0.5}},
		// AI TOOLS
		{appId: "^opencode$", opacity: 0.92, defaultColumnWidth: {proportion: 0.5}},
		{appId: "^code$", title: "^.*OpenCode.*$", opacity: 0.92, defaultColumnWidth: {proportion: 0.5}},
		{appId: "^electron$", title: "^Claude$", opacity: 0.65, defaultColumnWidth: {proportion: 0.45}},
		// SYSTEM TOOLS
		{appId: "yazi$", opacity: 0.85},
		{appId: "thunar$", opacity: 0.85},
		{appId: "btop$", opacity: 0.80},
		{appId: "pavucontrol$", openFloating: true, opacity: 0.92},
		{appId: "satty$", openFloating: true, opacity: 0.95, defaultColumnWidth: {proportion: 0.5}},
		{appId: "fuzzel$", openFloating: true, comment: "Launcher overlay"},
		// SCREENSHOT / RECORDING
		{appId: "^wf-recorder$", openFloating: true, opacity: 0.0},
		// CONTAINER / VM TOOLS
		{appId: "podman$", opacity: 0.85},
		{appId: "virt-viewer$", openFloating: true, opacity: 0.92},
		{appId: "^org\\.remmina\\.Remmina$", openFloating: true, opacity: 0.92},
		// SECURITY
		{appId: "^org\\.keepassxc\\.KeePassXC$", blockOutFrom: "screen-capture", opacity: 1.0},
		{appId: "^org\\.gnupg\\.pinentry$", openFloating: true, opacity: 1.0},
		{appId: "^ssh$", opacity: 0.85},
		// COMMUNICATION
		{appId: "^discord$", opacity: 0.90},
		{appId: "signal$", opacity: 0.90, defaultColumnWidth: {proportion: 0.5}},
		{appId: "element$", opacity: 0.90, defaultColumnWidth: {proportion: 0.5}},
	]
}
