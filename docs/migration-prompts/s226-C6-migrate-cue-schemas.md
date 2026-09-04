# Task S226-C6: Migrate CUE Schemas Niri → Hyprland

**Phase:** C (Config Migration)
**Model:** Ornith-1.0-9B (multi-file refactoring)
**Harness:** Pi (interactive — schema design needs iteration)
**Estimated context:** ~12K tokens
**Priority:** 1 (blocking C7 Go tools)
**Depends on:** C1 (keybindings), C2 (window rules), C3 (compositor)

---

## Background

The CUE migration toolchain generates Niri KDL from CUE data. The schemas are in `cue/`:

- `cue/cue.mod/module.cue` — module: `nightforge.niri`
- `cue/schema.cue` — `#Config`, `#Spawn`, `#Bind`, `#Action`, `#BuiltinAction`, `#SpawnAction`, `#WindowRule`, `#Width`
- `cue/nightforge.cue` — 8 spawns, 90 binds, 35 window rules (all Niri-specific)

These need to be migrated to a Hyprland CUE schema. The Niri schema has Niri-specific field names and action types. The Hyprland schema must use Hyprland dispatcher names and property names.

## Input: cue/schema.cue (85 lines — full)

```
package niri

#Config: {
    spawnAtStartup: [...#Spawn]
    binds: [...#Bind]
    windowRules: [...#WindowRule]
}

#Spawn: {
    argv: [string, ...string]
    comment?: string
}

#Bind: {
    combo: string
    action: #Action
    allowWhenLocked?: bool
    repeat?: bool
    hotkeyOverlayTitle?: string
    comment?: string
}

#Action: #SpawnAction | #BuiltinAction

#SpawnAction: {
    kind: "spawn"
    argv: [string, ...string]
}

#BuiltinAction: {
    kind: "builtin"
    name: string    // Niri action name, e.g. "focus-column-left"
    arg?: string
}

#WindowRule: {
    appId?: string
    title?: string
    opacity?: number
    openFloating?: bool          // Niri-specific
    openFullscreen?: bool        // Niri-specific
    clipToGeometry?: bool        // Niri-specific
    geometryCornerRadius?: int
    maxWidth?: int
    maxHeight?: int
    blockOutFrom?: string        // Niri-specific
    defaultColumnWidth?: #Width  // Niri-specific (column concept)
    defaultWindowHeight?: #Height // Niri-specific
    comment?: string
}

#Width: #Proportion | #Fixed
#Height: #Proportion | #Fixed

#Proportion: { proportion: number }
#Fixed: { fixed: int }
```

## Input: cue/nightforge.cue (key sections, 181 lines total)

**spawnAtStartup** (8 entries):
```
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
```

**binds** (90 entries — abbreviated examples):
```
binds: [
    {combo: "Mod+Shift+Slash", action: {kind: "builtin", name: "show-hotkey-overlay"}},
    {combo: "Mod+Return", action: {kind: "spawn", argv: ["ghostty"]}},
    {combo: "Mod+H", action: {kind: "builtin", name: "focus-column-left"}},           // → movefocus l
    {combo: "Mod+J", action: {kind: "builtin", name: "focus-window-or-workspace-down"}}, // → movefocus d
    {combo: "Mod+Q", action: {kind: "builtin", name: "close-window"}},                // → close
    {combo: "Mod+Space", action: {kind: "builtin", name: "toggle-overview"}},         // → overview:toggle
    {combo: "Mod+Shift+Space", action: {kind: "builtin", name: "toggle-window-floating"}}, // → togglefloating
    {combo: "Mod+1", action: {kind: "builtin", name: "focus-workspace", arg: "1"}},    // → workspace 1
    {combo: "Mod+Shift+1", action: {kind: "builtin", name: "move-column-to-workspace", arg: "1"}}, // → movetoworkspace 1
    {combo: "Mod+Ctrl+H", action: {kind: "builtin", name: "set-window-width", arg: "-10%"}}, // → resize: shrink 10
    {combo: "Mod+Ctrl+L", action: {kind: "builtin", name: "set-window-width", arg: "+10%"}}, // → resize: grow 10
    {combo: "Mod+Alt+Q", action: {kind: "builtin", name: "quit"}},                    // → exit
    // ... 79 more
]
```

**windowRules** (35 entries — abbreviated examples):
```
windowRules: [
    {geometryCornerRadius: 8, clipToGeometry: true, comment: "Global appearance"},
    {title: "^.*Preferences$", openFloating: true},
    {appId: "^waterfox$", opacity: 0.92, defaultColumnWidth: {proportion: 0.66667}},
    {appId: "^com\\.mitchellh\\.ghostty$", opacity: 0.65, defaultColumnWidth: {proportion: 0.5}},
    {appId: "obsidian$", opacity: 0.90, defaultColumnWidth: {proportion: 0.5}},
    {appId: "satty$", openFloating: true, opacity: 0.95, defaultColumnWidth: {proportion: 0.5}},
    // ... 30 more
]
```

## Hyprland Dispatcher Reference

Use the dispatcher names from Task C1's Hyprland API reference. Key Niri→Hyprland action name mappings:

| Niri Action | Hyprland Dispatcher |
|------------|-------------------|
| `close-window` | `close` |
| `quit` | `exit` |
| `toggle-overview` | `overview:toggle` |
| `toggle-window-floating` | `togglefloating` |
| `focus-column-left` | `movefocus l` |
| `focus-column-right` | `movefocus r` |
| `focus-window-or-workspace-down` | `movefocus d` |
| `focus-window-or-workspace-up` | `movefocus u` |
| `focus-workspace-down` | `workspace +1` |
| `focus-workspace-up` | `workspace -1` |
| `move-column-left` | `movefocus l` |
| `move-column-right` | `movefocus r` |
| `move-window-down-or-to-workspace-down` | `movedown` |
| `move-window-up-or-to-workspace-up` | `moveup` |
| `move-column-to-workspace N` | `movetoworkspace N` |
| `focus-workspace N` | `workspace N` |
| `focus-workspace-previous` | `workspace prev` |
| `maximize-column` | `fullscreen` |
| `center-column` | `centerwindow` |
| `consume-or-expel-window-left/right` | REMOVED |
| `toggle-column-tabbed-display` | REMOVED |
| `expel-window-from-column` | REMOVED |
| `switch-preset-column-width` | REMOVED |
| `set-window-width -10%` | `resize: shrink 10` |
| `set-window-width +10%` | `resize: grow 10` |
| `maximize-column` | `fullscreen` |
| `center-window` | `centerwindow` |
| `show-hotkey-overlay` | REMOVED (use omarchy menu) |
| `screenshot` | `exec grim` |
| `screenshot-window` | `exec grim -g "$(slurp -d)"` |

## Migration Requirements

1. **Update `cue/cue.mod/module.cue`**: Change `module: "nightforge.niri"` → `module: "nightforge.hypr"`

2. **Update `cue/schema.cue`**: 
   - Change `package niri` → `package hypr`
   - Rename `#BuiltinAction.name` field → keep as `name` but document that it's a Hyprland dispatcher string
   - Rename window rule fields: `openFloating` → `float`, `openFullscreen` → `fullscreen`, `defaultColumnWidth` → `width`, `defaultWindowHeight` → `height`, `clipToGeometry` → remove, `geometryCornerRadius` → `rounding`, `blockOutFrom` → remove
   - Add new Hyprland-specific sections: `#Decorations`, `#Animations`, `#InputConfig`
   - Update `#Width` to be a Hyprland width spec (pixels, not proportion)

3. **Update `cue/nightforge.cue`**:
   - Change `package niri` → `package hypr`
   - Update all 90 binds with Hyprland dispatcher names (use mapping table above)
   - Update all 35 window rules with Hyprland property names
   - Update 8 spawns (remove quickshell, replace matugen with aether)
   - Add compositor config section (gaps, rounding, animations, cursor, input)

## Expected Output

1. **`cue/cue.mod/module.cue`** — updated module name
2. **`cue/schema.cue`** — updated Hyprland CUE schema with all type definitions
3. **`cue/nightforge.cue`** — updated data with Hyprland dispatchers and property names

The CUE files should validate with: `cd cue && cue vet .`

## Acceptance Criteria

- `cue/cue.mod/module.cue`: module is `nightforge.hypr`
- `cue/schema.cue`: `package hypr`, all type definitions use Hyprland terminology
- `cue/nightforge.cue`: `package hypr`, all 90 binds use Hyprland dispatcher names, all 35 window rules use Hyprland property names
- 8 spawns updated (quickshell removed, matugen → aether)
- `cue vet .` passes
- `cue export . --out json` produces valid JSON
- All Niri-specific action names removed from the data

## Rollback

```bash
git checkout -- cue/
```

## References

- `docs/CUE-MIGRATION.md` — existing migration documentation
- `internal/nfutil/nfutil.go` — Go struct that mirrors CUE schema (needs updating in Task C7)
- Task C1 — keybinding mapping table
- Task C2 — window rule mapping table