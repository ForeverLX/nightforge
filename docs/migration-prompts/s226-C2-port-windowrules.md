# Task S226-C2: Port Window Rules Niri → Hyprland (windowrulev2)

**Phase:** C (Config Migration)
**Model:** Spark-X2.5-4B (code generation)
**Harness:** Pi (interactive)
**Estimated context:** ~12K tokens
**Priority:** 1 (critical — window behavior rules)

---

## Background

NightForge has 35 Niri window rules in `dotfiles/niri/.config/niri/includes/window-rules.kdl` (219 lines), mirrored in `cue/nightforge.cue`. These control per-app floating, opacity, column width, fullscreen, and screenshot blocking.

Niri window rules use KDL syntax:
```
window-rule {
    match app-id=r#"^waterfox$"#
    opacity 0.92
    default-column-width { proportion 0.66667; }
}
```

Hyprland uses `windowrulev2` directives in `.monitor`-level config or Lua:
```lua
o.window("app-id", "waterfox", { opacity = 0.92 })
```

## Input: Niri window-rules.kdl (full 219 lines)

```
// Window Rules - NightForge Operator Workstation

// GLOBAL APPEARANCE
window-rule {
    geometry-corner-radius 8
    clip-to-geometry true
}

// POPUP / MODAL FLOATING
window-rule { match title=r#"^.*Preferences$"# open-floating true }
window-rule { match title=r#"^.*Settings$"# open-floating true }
window-rule { match title=r#"^.*Save As$"# open-floating true }

// QUICKSHELL POPUPS
window-rule { match app-id=r#"^qs-"# open-floating true }
window-rule { match app-id=r#"^nightforge"# open-floating true }
window-rule { match title=r#"^NightForge Music$"# open-floating true default-column-width { proportion 0.5; } max-width 700 max-height 650 }

// BROWSERS
window-rule { match app-id=r#"^waterfox$"# opacity 0.92 default-column-width { proportion 0.66667; } }
window-rule { match app-id=r#"^waterfox$"# title=r#"^.*Picture-in-Picture$"# open-floating true max-width 400 max-height 300 }
window-rule { match title=r#"^.* — Waterfox$"# open-floating true }
window-rule { match app-id=r#"firefox$"# opacity 0.92 default-column-width { proportion 0.66667; } }
window-rule { match app-id=r#"firefox$"# title=r#"^.*Picture-in-Picture$"# open-floating true max-width 400 max-height 300 }

// TERMINALS
window-rule { match app-id=r#"^com\.mitchellh\.ghostty$"# opacity 0.65 default-column-width { proportion 0.5; } }
window-rule { match app-id=r#"^com\.mitchellh\.ghostty$"# title=r#"^tmux-picker$"# open-fullscreen true opacity 0.65 }
window-rule { match title=r#"^btop-monitor$"# open-floating true default-column-width { fixed 960; } default-window-height { fixed 700; } }

// NOTES (Obsidian)
window-rule { match app-id=r#"obsidian$"# opacity 0.90 default-column-width { proportion 0.5; } }

// AI TOOLS
window-rule { match app-id=r#"^opencode$"# opacity 0.92 default-column-width { proportion 0.5; } }
window-rule { match app-id=r#"^code$"# title=r#"^.*OpenCode.*$"# opacity 0.92 default-column-width { proportion 0.5; } }
window-rule { match app-id=r#"^electron$"# title=r#"^Claude$"# opacity 0.65 default-column-width { proportion 0.45; } }

// SYSTEM TOOLS
window-rule { match app-id=r#"yazi$"# opacity 0.85 }
window-rule { match app-id=r#"thunar$"# opacity 0.85 }
window-rule { match app-id=r#"btop$"# opacity 0.80 }
window-rule { match app-id=r#"pavucontrol"$# open-floating true opacity 0.92 }

// SCREENSHOT / RECORDING
window-rule { match app-id=r#"satty$"# open-floating true opacity 0.95 default-column-width { proportion 0.5; } }
window-rule { match app-id=r#"fuzzel$"# open-floating true }
window-rule { match app-id=r#"^wf-recorder$"# open-floating true opacity 0.0 }

// CONTAINER / VM TOOLS
window-rule { match app-id=r#"podman$"# opacity 0.85 }
window-rule { match app-id=r#"virt-viewer$"# open-floating true opacity 0.92 }
window-rule { match app-id=r#"^org\.remmina\.Remmina$"# open-floating true opacity 0.92 }

// SECURITY
window-rule { match app-id=r#"^org\.keepassxc\.KeePassXC$"# block-out-from "screen-capture" opacity 1.0 }
window-rule { match app-id=r#"^org\.gnupg\.pinentry$"# open-floating true opacity 1.0 }
window-rule { match app-id=r#"^ssh$"# opacity 0.85 }

// COMMUNICATION
window-rule { match app-id=r#"^discord$"# opacity 0.90 }
window-rule { match app-id=r#"signal$"# opacity 0.90 default-column-width { proportion 0.5; } }
window-rule { match app-id=r#"element$"# opacity 0.90 default-column-width { proportion 0.5; } }
```

## Hyprland Lua Window API

The local `~/.config/hypr/looknfeel.lua` is the target file for appearance rules.
The local `~/.config/hypr/bindings.lua` is for keybindings.

Hyprland Lua API for window rules uses `o.window()` and `o.workspace()`:

```lua
-- Format: o.window(match_field, match_value, { properties })
-- match_field: "app-id" or "title" (use regex patterns)
-- Properties: opacity, rounding, blur, border, size, position, float, fullscreen, etc.

-- Example mappings:
o.window("app-id", "firefox", { rounding = 8 })
o.window("title", "Preferences", { float = true })
o.window("app-id", "gh", { border = false })
o.workspace("1", { monitor = 0, default = false })

-- Available properties (subset):
-- float = true/false
-- opacity = { 0.9, 0.9 }  (inactive, active)
-- rounding = 8
-- border = false
-- blur = { enabled = true, size = 4, passes = 2 }
-- size = { 700, 650 }
-- fullscreen = true (or "1" for maximize, "0" for unmassimize)
-- pin = true
-- center = true
-- minsize = { 800, 600 }
-- maxsize = { 1600, 900 }
```

Hyprland `windowrulev2` equivalent (if using raw config):
```
windowrulev2 = float, title:^(.*Preferences.*)$
windowrulev2 = opacity 0.92, class:^(waterfox)$
windowrulev2 = fullscreen, title:^(tmux-picker)$
windowrulev2 = size 960 700, title:^(btop-monitor)$
```

## Mapping Rules

1. **`geometry-corner-radius 8`** → `rounding = 8` in looknfeel.lua (global)
2. **`clip-to-geometry true`** → Hyprland handles this differently; use `border = false` + `rounding = 8`
3. **`open-floating true`** → `float = true`
4. **`open-fullscreen true`** → `fullscreen = true` (or `fullscreen = 1`)
5. **`opacity X`** → `opacity = { X, X }` (same for active/inactive) or `opacity = X` in Lua context
6. **`default-column-width { proportion P }`** → Hyprland doesn't have column widths; use `size = { P * 1920, -1 }` for approximate width
7. **`default-column-width { fixed N }`** → `size = { N, -1 }`
8. **`default-window-height { fixed N }`** → `size = { -1, N }`
9. **`max-width N` / `max-height N`** → `maxsize = { N, N }` (or use `size = { N, -1 }`)
10. **`block-out-from "screen-capture"`** → Hyprland: `noborder` or `opacity` on lock screen; for screen capture blocking use `lock` + `noanim`. No direct equivalent; document as limitation.

## Expected Output

**Part 1**: Update `~/.config/hypr/looknfeel.lua` with global appearance rules:
```lua
-- Global appearance
o.config({
  decoration = {
    rounding = 8,
    -- ... etc
  }
})
```

**Part 2**: Create a new section in `looknfeel.lua` or a separate `window-rules.lua` file with all 35 window rules as `o.window()` calls.

**Part 3**: Update `cue/nightforge.cue` to reflect the Hyprland window rule data (keeping the CUE source of truth for the new format).

## Acceptance Criteria

- All 35 window rules mapped to Hyprland format
- Global appearance rules (corner radius, clip) applied in looknfeel.lua
- Float rules mapped to `float = true`
- Opacity rules mapped correctly
- Fullscreen rules mapped (`fullscreen = true`)
- Size constraints mapped (`size = { W, H }` or `maxsize`)
- `block-out-from "screen-capture"` documented as limitation (no direct Hyprland equivalent)
- Updated cue/nightforge.cue reflects Hyprland window rules
- `bash -n` passes on any shell scripts; `luac -p` validates Lua syntax

## Rollback

```bash
cp dotfiles/niri/.config/niri/includes/window-rules.kdl dotfiles/niri/.config/niri/includes/window-rules.kdl.S226-backup
```