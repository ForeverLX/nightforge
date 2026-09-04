# Task S226-C1: Port Keybindings Niri → Hyprland (bindings.lua)

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation, best SWE-Bench Pro)
**Harness:** Pi (interactive — may need iteration)
**Estimated context:** ~10K tokens
**Priority:** 1 (critical — keybindings are core to daily workflow)

---

## Background

NightForge has 90 Niri keybindings across two sources:
1. `dotfiles/niri/.config/niri/includes/keybinds.kdl` (144 lines) — the live config
2. `cue/nightforge.cue` (181 lines) — the CUE data source of truth

Both must be kept in sync (verified by `fidelity-check`). The local Hyprland config at `~/.config/hypr/bindings.lua` is currently empty (just Omarchy template comments).

Niri uses a **column-based scrolling layout** with Niri-specific actions (`focus-column-left`, `move-column-to-workspace`, `toggle-column-tabbed-display`, `consume-or-expel-window-left`). Hyprland uses a **workspace + master/stack layout** with standard dispatchers (`movefocus`, `movetoworkspace`, `resize`).

## Input: Niri keybinds.kdl (144 lines)

Full file content:

```
binds {
    Mod+Shift+Slash { show-hotkey-overlay; }
    Mod+Slash { spawn "sh" "-c" "~/.config/niri/scripts/keybind-cheatsheet.sh"; }
    Mod+Return { spawn "ghostty"; }
    Mod+D { spawn "fuzzel"; }
    Mod+B { spawn "sh" "-c" "~/.config/niri/scripts/focus-or-spawn.sh firefox"; }
    Mod+F { spawn "ghostty" "-e" "yazi"; }
    Mod+Shift+C { spawn "sh" "-c" "echo settings > /tmp/qs_widget_state"; }
    Mod+M { spawn "sh" "-c" "echo music > /tmp/qs_widget_state"; }
    Mod+Shift+N { spawn "sh" "-c" "echo network > /tmp/qs_widget_state"; }
    Mod+Shift+W { spawn "sh" "-c" "echo wallpaper > /tmp/qs_widget_state"; }
    Mod+Shift+Comma { spawn "sh" "-c" "echo settings > /tmp/qs_widget_state"; }
    Mod+Shift+V { spawn "sh" "-c" "echo clipboard > /tmp/qs_widget_state"; }
    Mod+Shift+D { spawn "sh" "-c" "echo dashboard > /tmp/qs_widget_state"; }
    Mod+Escape { spawn "sh" "-c" "echo close > /tmp/qs_widget_state"; }
    Print { screenshot; }
    Alt+Print { screenshot-window; }
    Mod+S { spawn "sh" "-c" "~/.config/niri/scripts/screenshot.sh area-clipboard"; }
    Mod+Shift+R { spawn "sh" "-c" "~/.config/niri/scripts/screen-record.sh"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "raise"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "swayosd-client" "--output-volume" "lower"; }
    XF86AudioMute allow-when-locked=true { spawn "swayosd-client" "--output-volume" "toggle"; }
    XF86AudioMicMute allow-when-locked=true { spawn "swayosd-client" "--input-volume" "toggle"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "swayosd-client" "--brightness" "raise"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "swayosd-client" "--brightness" "lower"; }
    XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
    XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
    XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
    Mod+V { spawn "sh" "-c" "~/.local/bin/clipboard-picker.sh"; }
    Mod+Alt+L { spawn "sh" "-c" "~/.config/quickshell/scripts/lock-screen.sh"; }
    Mod+Alt+Q { quit; }
    Mod+Shift+E { spawn "bash" "$HOME/Github/nightforge/scripts/engagement-edit.sh"; }
    Mod+Q { close-window; }
    Mod+Space repeat=false hotkey-overlay-title="Toggle overview" { toggle-overview; }
    Mod+Shift+Space { toggle-window-floating; }
    Mod+Shift+X { maximize-column; }
    Mod+W { toggle-column-tabbed-display; }
    Mod+G { toggle-window-floating; }
    Mod+C { center-column; }
    Mod+Backslash { spawn "bash" "-c" "~/.config/quickshell/scripts/niri_tweaks/tweaks window-details"; }
    Mod+Alt+C hotkey-overlay-title="Center Window" { center-window; }
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+J { focus-window-or-workspace-down; }
    Mod+K { focus-window-or-workspace-up; }
    Mod+U { focus-workspace-down; }
    Mod+I { focus-workspace-up; }
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    Mod+Shift+J { move-window-down-or-to-workspace-down; }
    Mod+Shift+K { move-window-up-or-to-workspace-up; }
    Mod+Shift+Left { move-column-to-monitor-left; }
    Mod+Shift+Right { move-column-to-monitor-right; }
    Mod+Alt+Left { focus-monitor-left; }
    Mod+Alt+Right { focus-monitor-right; }
    Mod+BracketLeft { consume-or-expel-window-left; }
    Mod+BracketRight { consume-or-expel-window-right; }
    Mod+Period { expel-window-from-column; }
    Mod+Tab { focus-workspace-previous; }
    Mod+A { spawn "sh" "-c" "~/.local/bin/audio-switch.sh toggle"; }
    Mod+1..9 { focus-workspace "1".."9"; }
    Mod+Shift+1..9 { move-column-to-workspace "1".."9"; }
    Mod+Ctrl+H { set-window-width "-10%"; }
    Mod+Ctrl+L { set-window-width "+10%"; }
    Mod+Ctrl+J { set-window-height "-10%"; }
    Mod+Ctrl+K { set-window-height "+10%"; }
    Mod+R { switch-preset-column-width; }
    Mod+Alt+D { spawn "obsidian" "obsidian://daily"; }
    Mod+Shift+O { spawn "obsidian" "obsidian://search"; }
    Mod+O { spawn "obsidian" "obsidian://open?vault=azrael-vault"; }
    Mod+Shift+P { spawn "bash" "$HOME/Github/nightforge/scripts/toggle-performance-mode.sh"; }
    Mod+Alt+R { spawn "bash" "-c" "~/.local/bin/wallpaper-rotate.sh --notify && ~/.local/bin/matugen-sync.sh $(cat ~/.cache/current_wallpaper)"; }
    Mod+Shift+G { spawn "ghostty" "-e" "cat ~/.config/nightforge/engagement-context 2>/dev/null || echo 'No active engagement'"; }
    Mod+Shift+T { spawn "ghostty" "-e" "podman ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"; }
}
```

## Hyprland Lua API Reference

The local `~/.config/hypr/bindings.lua` uses Omarchy's `o.bind()` API:

```lua
-- Format: o.bind("MODIFIER + KEY", "description", "command")
-- To bind without description: o.bind("MODIFIER + KEY", nil, "command")
-- To unbind: hl.unbind("MODIFIER + KEY")

-- Hyprland key modifiers: SUPER, SHIFT, CTRL, ALT, CAPS, NUMLOCK
-- Key names: Return, D, B, F, Space, Q, Escape, Comma, Period
--           1-9, BracketLeft, BracketRight, Backslash, Minus, Equal
--           H, J, K, L, U, I, W, R, G, A, M, N, V
--           Plus, Minus, XF86AudioRaiseVolume, XF86AudioMute, etc.

-- Dispatcher reference (what goes in "command" slot):
--   "exec ghostty"                    — spawn app
--   "exec sh -c '...'"               — spawn with shell
--   "movefocus l/r/u/d"              — focus window left/right/up/down
--   "workspace 1" / "workspace +1"   — switch workspace
--   "movetoworkspace 1"              — move window to workspace
--   "moveworkspacetomonitor +1"      — send workspace to next monitor
--   "focusmonitor +1" / "-1"         — focus next/prev monitor
--   "togglefloating"                 — toggle floating
--   "close"                          — close window
--   "exit"                           — quit compositor
--   "fullscreen"                     — toggle fullscreen
--   "centerwindow"                   — center active window
--   "resize: shrink 10" / "grow 10"  — resize window
--   "overview:toggle"                — toggle overview (hyprgrass plugin)
--   "overview:shift +1"              — overview workspace navigation
```

## Mapping Rules

Map each Niri keybinding to its Hyprland equivalent. Use this priority:

1. **Direct equivalents**: Use Hyprland dispatcher directly (e.g., `close-window` → `close`, `quit` → `exit`)
2. **Conceptual equivalents**: Map to closest Hyprland dispatcher (e.g., `focus-column-left` → `movefocus l`)
3. **Column-specific Niri actions** (no Hyprland equivalent):
   - `maximize-column` → `fullscreen`
   - `toggle-column-tabbed-display` → remove (Hyprland doesn't have tabbed columns natively)
   - `consume-or-expel-window-*` → remove (Niri-specific column management)
   - `switch-preset-column-width` → remove
   - `center-column` → `centerwindow`
4. **Quickshell widget toggles** (Mod+Shift+C, Mod+M, etc.): Replace with Waybar/Hyprland overlay commands. Since Waybar replaces quickshell, these should trigger Waybar custom modules or be removed if Waybar has its own toggles.
5. **Niri scripts**: Replace `~/.config/niri/scripts/` paths with `~/.local/bin/` or `~/.config/hypr/scripts/`
6. **Focus-or-spawn**: Adapt to use `hyprctl` instead of `niri msg` (Task C8 will handle this)
7. **Screenshot**: Map Niri `screenshot`/`screenshot-window` to `grim` + `slurp`
8. **XF86 keys**: Keep as-is (swayosd and playerctl work in Hyprland)
9. **Mod+Alt+R (wallpaper rotation)**: Replace matugen-sync.sh call with Aether equivalent: `awww img <wallpaper>` + `~/.local/bin/aether-sync.sh`

## Expected Output

Write the file `~/.config/hypr/bindings.lua` using the Omarchy `o.bind()` API. Include:
- All 90 keybindings mapped (or clearly commented as removed)
- Comments explaining non-obvious mappings
- A "Removed (Niri-specific)" section listing actions with no Hyprland equivalent

Format:
```lua
-- NightForge keybindings — ported from Niri keybinds.kdl
-- Generated: S226 migration

-- === HELP ===
-- Niri: show-hotkey-overlay → Hyprland: no direct equivalent (use omarchy menu)
-- Keybind cheatsheet (Spoon's keybindings reference)
o.bind("SUPER + SLASH", "Keybind cheatsheet", "exec sh -c '~/.local/bin/keybind-cheatsheet.sh'")

-- === APPLICATIONS ===
o.bind("SUPER + RETURN", "Terminal", "exec ghostty")
o.bind("SUPER + D", "App launcher", "exec fuzzel")
...

-- === REMOVED (Niri-specific column management) ===
-- toggle-column-tabbed-display: Niri-only, no Hyprland equivalent
-- consume-or-expel-window-left/right: Niri-only
-- switch-preset-column-width: Niri-only

-- === WORKSPACES ===
-- ... etc
```

## Acceptance Criteria

- All 90 keybindings mapped (direct, conceptual, or removed-with-comment)
- No `niri msg` or Niri-specific commands remain
- File is valid Lua (syntax check with `luac -p`)
- Comments explain all non-obvious mappings
- "Removed" section lists all Niri-only actions with rationale
- Quickshell widget toggle bindings are adapted for Waybar
- Screenshot bindings use `grim`/`slurp` or `satty` as appropriate

## Rollback

Save a copy of the original Niri keybinds.kdl before making changes:
```bash
cp ~/.config/niri/includes/keybinds.kdl ~/.config/niri/includes/keybinds.kdl.S226-backup
```