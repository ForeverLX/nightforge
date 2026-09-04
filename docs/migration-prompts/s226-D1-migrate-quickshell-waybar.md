# Task S226-D1: Migrate Quickshell Bar → Waybar

**Phase:** D (Service Migration)
**Model:** Spark-X2.5-4B (code generation, large output)
**Harness:** Pi (interactive — QML → JSON is complex)
**Estimated context:** ~18K tokens
**Priority:** 2
**Depends on:** C1 (keybindings), C3 (compositor), C5 (theming)

---

## Background

The NightForge desktop uses a custom QML bar built with Quickshell (`modules/Bar.qml`, 311 lines, plus `dotfiles/quickshell/` deploy copy). It polls `niri msg` for workspace data, reads `/tmp/matugen/colors.json` for theming, and displays system status (clock, battery, MPD, Podman, VPN, engagement context, performance mode).

The local `~/.config/hypr/` has Omarchy defaults which include Waybar. The goal: migrate the quickshell bar's functionality to a Waybar configuration that uses `hyprctl` instead of `niri msg` and Aether colors instead of matugen.

The ARCHITECTURE.md says quickshell *can* stay if Hyprland-compatible, but the ARCHITECTURE diagrams and Bar.qml both use `niri msg` extensively — a full Waybar port is cleaner and aligns with Omarchy defaults.

## Input: modules/Bar.qml (311 lines — key structure)

The bar has these components:
1. **Workspace polling** (lines 12-55): `niri msg --json workspaces` + `niri msg --json active-workspace`
2. **Clock** (lines 57-68): `Qt.formatDateTime(new Date(), "hh:mm")` + date display
3. **Battery** (lines 70-89): `cat /sys/class/power_supply/BAT*/capacity`
4. **Engagement context** (lines 91-119): `cat $HOME/.config/nightforge/engagement-context`
5. **Performance mode** (lines 121-147): `cat $HOME/.config/nightforge/performance-mode` — toggle via `toggle-performance-mode.sh`
6. **Bar layout** (lines 155-310):
   - **Left (workspaces)**: 5 workspace buttons (1-5), click to focus via `niri msg action focus-workspace`
   - **Center (clock)**: bold clock + date
   - **Right (status indicators)**:
     - Performance mode (click to toggle)
     - Engagement context (click to edit)
     - MPD status (click to play/pause)
     - Podman status (container count)
     - VPN status (click to toggle)
     - Battery
     - Date

## Input: Services that Bar.qml depends on

### services/MatugenColors.qml (70 lines)
- Reads `cat /tmp/matugen/colors.json` every 5s
- Properties: primary, surface, onSurface, outline, surfaceVariant, error, secondary, tertiary, performanceMode
- Used by: Bar.qml references `MatugenColors.primary`, `MatugenColors.surface`, etc.

### services/MpdClient.qml, VpnStatus.qml, PodmanStatus.qml
- These are status services that read from system commands
- Used by Bar.qml for display

## Quickshell scripts to port

### scripts/workspaces.sh (20 lines)
```bash
# Niri workspace daemon
niri msg --json workspaces 2>/dev/null | jq ...
# → Port to:
hyprctl workspaces -j | jq ...
```

### scripts/qs_manager.sh (103 lines)
- Widget IPC router via `/tmp/qs_widget_state`
- In Waybar, widgets are toggled via `omarchy-menu` or custom scripts
- Most functionality is quickshell-specific and not needed in Waybar

### scripts/lock-screen.sh, music_info.sh
- Already WM-agnostic (gtklock/swaylock, playerctl)
- Can be reused in Hyprland

## Waybar Configuration Format

Waybar uses:
- `~/.config/waybar/config` (JSON array of bar configs)
- `~/.config/waybar/style.css` (CSS for styling)
- `~/.config/waybar/modules/` (custom script modules)

Waybar modules:
- `hyprland/workspaces` — workspace buttons (auto-replaces niri msg)
- `hyprland/window` — window title
- `clock` — clock + tooltip with calendar
- `battery` — battery percentage
- `pulseaudio` — volume
- `network` — network status
- `backlight` — brightness
- `cpu` / `memory` / `temperature` — system monitor
- `custom` — custom scripts for MPD, Podman, VPN, engagement

Waybar config example:
```json
{
  "layer": "top",
  "position": "top",
  "height": 32,
  "modules-left": ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["clock"],
  "modules-right": ["pulseaudio", "network", "battery", "custom/podman", "custom/vpn", "custom/engagement", "custom/performance"],
  "custom/performance": {
    "format": "{}",
    "exec": "~/.local/bin/performance-mode.sh status",
    "on-click": "bash ~/.local/bin/toggle-performance-mode.sh"
  }
}
```

## Aether Color Integration

The `matugen-sync.sh` (Task C5) will generate Aether colors. For Waybar, Aether provides colors via:
- `omarchy theme get-colors` → JSON output
- Or `~/.cache/omarchy/colors.json` file

Waybar CSS can use these via CSS variables. The `style.css` should define colors matching the Aether palette.

## Expected Output

1. **`~/Projects/nightforge/dotfiles/waybar/.config/waybar/config`** — Waybar config JSON
   - Mirrors Bar.qml layout: left=workspaces, center=clock, right=status
   - Hyprland workspace module replaces niri msg polling
   - Custom modules for: MPD, Podman, VPN, engagement context, performance mode
   - All custom modules use `exec` + `interval` + `on-click` pattern

2. **`~/Projects/nightforge/dotfiles/waybar/.config/waybar/style.css`** — CSS styling
   - Matches NightForge dark theme (primary #cba6f7, surface #1e1e2e)
   - Uses Aether color variables where possible

3. **Custom module scripts** (in `dotfiles/waybar/.config/waybar/scripts/`):
   - `engagement.sh` — reads engagement-context file, outputs for Waybar
   - `performance.sh` — reads/writes performance-mode file
   - `podman.sh` — container status
   - `vpn.sh` — WireGuard status via `wg show`
   - `mpd.sh` — MPRIS status via `playerctl`

4. **`dotfiles/waybar/.config/waybar/config`** must be added to `scripts/apply-dotfiles.sh` package list

5. **Remove** `dotfiles/quickshell/` (or mark as deprecated — see ARCHITECTURE.md note about keeping quickshell if Hyprland-compatible)

## Acceptance Criteria

- Waybar config replaces all quickshell bar functionality (workspaces, clock, battery, MPD, Podman, VPN, engagement, performance)
- Workspace module uses `hyprland/workspaces` (no `niri msg` calls)
- Custom scripts for each status indicator (MPD, Podman, VPN, engagement, performance)
- CSS file uses NightForge color palette + Aether variables
- Custom scripts are executable and output valid JSON for Waybar
- Package added to `dotfiles/apply-dotfiles.sh` stow list
- `dotfiles/waybar/` directory created with all files
- No `niri` or `matugen` references in the new Waybar config

## Rollback

```bash
rm -rf ~/Projects/nightforge/dotfiles/waybar/
# The original quickshell config in dotfiles/quickshell/ is untouched
```