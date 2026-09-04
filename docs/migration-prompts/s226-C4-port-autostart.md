# Task S226-C4: Port Autostart Spawns Niri → Hyprland

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation)
**Harness:** Pi (interactive)
**Estimated context:** ~5K tokens
**Priority:** 2

---

## Background

The local `~/.config/hypr/autostart.lua` (2 lines) is an empty template. The Niri source config in `dotfiles/niri/.config/niri/config.kdl` has 8 spawn-at-startup entries. The CUE data in `cue/nightforge.cue` mirrors these.

Hyprland uses `exec-once` or Omarchy's `o.launch_on_start()` API for autostart. The local `hyprland.lua` already bootstraps Omarchy defaults.

## Input: Niri spawn-at-startup (from config.kdl, 19 lines)

```
spawn-at-startup "awww-daemon"                     # Wallpaper daemon
spawn-at-startup "bash" "-c" "quickshell &"        # Quickshell overlay
spawn-at-startup "bash" "-c" "sleep 1 && quickshell -p $HOME/.config/quickshell/TopBar.qml &"  # Quickshell TopBar
spawn-at-startup "bash" "-c" "sleep 2 && $HOME/.local/bin/matugen-sync.sh $HOME/Pictures/wallpapers/current.jpg"  # Matugen sync
spawn-at-startup "systemctl" "--user" "start" "podman-restart.service"   # Podman services
spawn-at-startup "systemctl" "--user", "enable" "--now" "wallpaper-rotate.timer"   # Wallpaper rotation
spawn-at-startup "bash" "-c" "sleep 2 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=niri"  # Screensharing env
spawn-at-startup "systemctl" "--user", "start" "mpd.service"   # MPD
```

## Input: Local Hyprland autostart.lua (2 lines)

```lua
-- Extra autostart processes.
-- o.launch_on_start("my-service")
```

## Hyprland Autostart API

Omarchy provides `o.launch_on_start()` for autostart commands. Hyprland also supports `exec-once` via `hl.exec()`.

```lua
-- Omarchy API:
o.launch_on_start("command string")

-- Raw Hyprland API:
hl.exec("command string")

-- Examples from Omarchy defaults:
o.launch_on_start("systemctl --user start podman-restart.service")
o.launch_on_start("systemctl --user enable --now wallpaper-rotate.timer")
o.launch_on_start("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
```

## Migration Mapping

| Niri Spawn | Hyprland Equivalent | Notes |
|-----------|-------------------|-------|
| `awww-daemon` (wallpaper) | `o.launch_on_start("awww-daemon")` | Keep awww (wallpaper daemon) |
| `quickshell &` (overlay) | REMOVE | Quickshell replaced by Waybar/Omarchy shell |
| `quickshell -p TopBar.qml` | REMOVE | Replaced by Omarchy bar/Waybar |
| `matugen-sync.sh` | Replace with Aether | `o.launch_on_start("aether theme set ~/.cache/current_wallpaper")` or equivalent |
| `podman-restart.service` | Keep as-is | `systemctl --user start` |
| `wallpaper-rotate.timer` | Keep as-is | Already works with systemd |
| `dbus-update-activation-environment ... niri` | Change `niri` to `Hyprland` | Wayland env var for screensharing |
| `mpd.service` | Keep as-is | Already in autostart at ~/.config/hypr/hyprland.lua via Omarchy |

## Expected Output

Update `~/.config/hypr/autostart.lua` to include all necessary autostart entries:

1. Keep: `awww-daemon` (wallpaper daemon)
2. Keep: `podman-restart.service`
3. Keep: `wallpaper-rotate.timer`
4. Keep: `mpd.service` (or confirm it's handled by Omarchy)
5. Replace: `matugen-sync.sh` → Aether equivalent
6. Replace: quickshell spawns → REMOVE (handled by Omarchy bar)
7. Fix: `XDG_CURRENT_DESKTOP=niri` → `XDG_CURRENT_DESKTOP=Hyprland`

Format:
```lua
-- NightForge autostart — ported from Niri config.kdl
-- Replaces spawn-at-startup entries

-- Wallpaper daemon
o.launch_on_start("awww-daemon")

-- Podman services
o.launch_on_start("systemctl --user start podman-restart.service")

-- Wallpaper rotation timer
o.launch_on_start("systemctl --user enable --now wallpaper-rotate.timer")

-- Screensharing env
o.launch_on_start("bash -c 'sleep 2 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland'")

-- MPD (if not handled by Omarchy)
o.launch_on_start("systemctl --user start mpd.service")

-- Aether theming (replaces matugen-sync.sh)
o.launch_on_start("aether theme set $HOME/Pictures/wallpapers/current.jpg")

-- REMOVED: quickshell spawns (replaced by Omarchy Waybar)
-- o.launch_on_start("quickshell &")      -- removed: using Omarchy bar
-- o.launch_on_start("quickshell -p ...") -- removed: using Omarchy bar
```

## Acceptance Criteria

- All 8 Niri spawn entries accounted for (keep/adapt/remove)
- Quickshell spawns removed (3 entries)
- Matugen replaced with Aether
- `XDG_CURRENT_DESKTOP=Hyprland` (not `niri`)
- awww-daemon, podman, wallpaper-rotate.timer, mpd all present
- `luac -p autostart.lua` passes syntax check
- No `quickshell` or `matugen` or `niri` references remain

## Rollback

```bash
cp autostart.lua.S226-backup autostart.lua 2>/dev/null || true
```