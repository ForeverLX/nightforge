# Task S226-C3: Port Compositor Config (input + looknfeel) Niri → Hyprland

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation)
**Harness:** Pi (interactive)
**Estimated context:** ~8K tokens
**Priority:** 1 (critical — core WM behavior)

---

## Background

The local `~/.config/hypr/` already has Omarchy-based Hyprland config files:
- `hyprland.lua` (29 lines) — bootstraps from `/usr/share/omarchy`
- `bindings.lua` (29 lines) — empty template (target for Task C1)
- `input.lua` (57 lines) — empty template (port keyboard/mouse/touchpad config here)
- `looknfeel.lua` (50 lines) — empty template (port compositor layout, animations, gaps here)
- `monitors.lua` (14 lines) — monitor config (already partially set)
- `autostart.lua` (2 lines) — empty template (port spawn-at-startup here, Task C4)

The Niri source configs to port:
- `dotfiles/niri/.config/niri/includes/input.kdl` (34 lines) — keyboard, touchpad, mouse
- `dotfiles/niri/.config/niri/includes/compositor.kdl` (83 lines) — layout, gaps, animations, cursor
- `dotfiles/niri/.config/niri/includes/colors.kdl` (2 lines) — auto-generated (will be empty under Aether)

## Input: Niri input.kdl (34 lines)

```
input {
    keyboard {
        xkb { layout "us" }
        numlock
        repeat-delay 250
        repeat-rate 40
    }
    touchpad {
        tap
        natural-scroll
    }
    mouse {
        natural-scroll
        accel-speed 0.0
        accel-profile "flat"
    }
    warp-mouse-to-focus
    focus-follows-mouse max-scroll-amount="0%"
}
```

## Input: Niri compositor.kdl (83 lines)

```
prefer-no-csd
layout {
    gaps 8
    center-focused-column "never"
    preset-column-widths { proportion 0.33333; proportion 0.5; proportion 0.66667; }
    default-column-width { proportion 0.5; }
    struts { top 48 }
    border { off }
    shadow { /* commented out */ }
    focus-ring { off }
}
cursor { xcursor-theme "Adwaita"; xcursor-size 24; }
animations {
    slowdown 0.5
    window-open { duration-ms 80; curve "ease-out-cubic" }
    window-close { duration-ms 80; curve "ease-out-expo" }
    workspace-switch { duration-ms 80; curve "ease-out-cubic" }
}
screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
hotkey-overlay { skip-at-startup }
```

## Hyprland Lua API Reference

The Omarchy `hl.config()` API mirrors Hyprland's config structure. The local `input.lua` and `looknfeel.lua` already have commented-out template examples:

```lua
-- input.lua — keyboard, mouse, touchpad
hl.config({
  input = {
    kb_layout = "us",
    kb_options = "compose:caps,shift:both_capslock_cancel",
    numlock_by_default = true,
    repeat_rate = 40,
    repeat_delay = 250,
    sensitivity = 0.35,
    accel_profile = "flat",
    natural_scroll = true,
    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
      disable_while_typing = false,
    },
  },
})

-- looknfeel.lua — appearance, gaps, animations
hl.config({
  general = {
    gaps_in = 8,
    gaps_out = 8,
    border_size = 0,
    col.active_border = 0x89b4fa,
    col.inactive_border = 0x45475a,
  },
  decoration = {
    rounding = 8,
    dim_inactive = true,
    dim_strength = 0.15,
    blur = { enabled = true, size = 4, passes = 2 },
  },
  animations = {
    enabled = true,
    smoothness = 0.1,
    animation = { "windows, 1, 80, default", "fade, 1, 80, default" },
  },
  layout = {
    default = "master",
  },
})

-- Monitor struts (panel reserved space):
-- Hyprland uses monitor reserved area:
hl.config({
  monitor = {
    reserved = "48,0,0,0",  -- top=48, right=0, bottom=0, left=0
  },
})

-- Screenshot path:
-- Hyprland uses grim + slurp; path set via SHELL script or hyprpicker
```

## Mapping Rules

1. **Keyboard**: `xkb.layout "us"` → `kb_layout = "us"`, `numlock` → `numlock_by_default = true`, `repeat-delay 250` → `repeat_delay = 250`, `repeat-rate 40` → `repeat_rate = 40`
2. **Touchpad**: `tap` → not a direct Hyprland setting (Niri-specific), `natural-scroll` → `natural_scroll = true`
3. **Mouse**: `natural-scroll` → `natural_scroll = true`, `accel-speed 0.0` → `sensitivity = 0.0`, `accel-profile "flat"` → `accel_profile = "flat"`
4. **warp-mouse-to-focus**: No direct Hyprland equivalent (Hyprland focuses without warping by design)
5. **focus-follows-mouse**: Hyprland doesn't support this natively (would need a daemon)
6. **Layout**: `gaps 8` → `gaps_in = 8, gaps_out = 8`, `border { off }` → `border_size = 0`, `corner-radius 8` → `rounding = 8`
7. **preset-column-widths** + **default-column-width**: Niri-specific column concept; Hyprland uses master/stack layout
8. **struts { top 48 }**: → `reserved = "48,0,0,0"` in monitor config for top panel
9. **animations**: Map `slowdown 0.5` + duration/curve to Hyprland animation `speed`/`curve`
10. **cursor theme**: `xcursor-theme "Adwaita"; xcursor-size 24` → `hl.config({ cursor = { theme = "Adwaita", size = 24 } })`
11. **prefer-no-csd**: Omarchy handles this; no Hyprland config needed
12. **screenshot-path**: Not a Hyprland config option; use grim/satty with custom output path
13. **hotkey-overlay**: No Hyprland equivalent; use `omarchy menu keybindings`

## Expected Output

1. **Update `~/.config/hypr/input.lua`**: Uncomment and fill in the input config with Niri keyboard/mouse/touchpad settings mapped to Hyprland equivalents. Note Niri features that can't be ported (warp-mouse-to-focus, focus-follows-mouse).

2. **Update `~/.config/hypr/looknfeel.lua`**: Uncomment and fill in:
   - `general` (gaps, border_size=0, active/inactive border color)
   - `decoration` (rounding=8 from corner-radius, dim settings)
   - `animations` (map from Niri animation speeds)
   - `cursor` (theme, size)
   - `layout` (set default to "master" — closest to Niri's column layout)
   - `monitor` reserved area (top 48px for panel)

3. **Document unmappable Niri features** in comments.

## Acceptance Criteria

- `input.lua` has keyboard (us layout, numlock, repeat rate/delay), touchpad (tap, natural scroll), mouse (flat accel, sensitivity 0) settings
- `looknfeel.lua` has gaps_in=8, gaps_out=8, border_size=0, rounding=8, cursor theme/size, animations enabled with snappy curve
- Monitor reserved top area (48px) configured for panel
- Comments document all unmappable Niri features (focus-follows-mouse, warp-mouse-to-focus, column-width presets, hotkey-overlay)
- `luac -p input.lua` and `luac -p looknfeel.lua` pass syntax check

## Rollback

```bash
cp ~/.config/hypr/input.lua.S226-backup ~/.config/hypr/input.lua 2>/dev/null || true
cp ~/.config/hypr/looknfeel.lua.S226-backup ~/.config/hypr/looknfeel.lua 2>/dev/null || true
```