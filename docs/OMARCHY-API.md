# Omarchy API Reference

Discovered during S226 migration planning. Omarchy provides a Lua-based Hyprland
configuration system at `/usr/share/omarchy/default/hypr/`. User overrides go in
`~/.config/hypr/` (loaded after defaults).

## Core Lua API

### Keybindings: `o.bind()`

```lua
-- Format: o.bind("MODIFIER + KEY", "description", "command")
o.bind("SUPER + RETURN", "Terminal", "exec ghostty")

-- Without description
o.bind("SUPER + D", nil, "exec fuzzel")

-- Unbind a default binding
hl.unbind("SUPER + SHIFT + B")

-- Toggle binding (for boolean settings)
o.bind_toggle("XF86TouchpadToggle", "Toggle touchpad", "touchpad", { locked = true })

-- With options (locked = works on lock screen)
o.bind("XF86AudioRaiseVolume", "Volume up", "omarchy-audio-output-volume raise", { locked = true })
```

### Window Rules: `o.window()`

```lua
-- Match by class (app-id)
o.window("^(firefox)$", { opacity = "1.0 0.985" })

-- Match by class + title
o.window({ class = "^waterfox$", title = "^.*PiP.*$" }, { float = true, center = true })

-- Match by tag (previously set)
o.window({ tag = "chromium-based-browser" }, { tag = "-default-opacity", tile = true })

-- Available properties:
--   float = true/false
--   center = true
--   fullscreen = true
--   opacity = "active inactive"  (e.g. "1.0 0.985")
--   size = { width, height }  (e.g. { 1100, 700 })
--   tag = "+tag-name" or "-tag-name"
--   tile = true/false
--   workspace = "special silent"
--   no_screen_share = true
--   no_follow_mouse = true
--   idle_inhibit = "fullscreen"
--   stay_focused = false
```

### Config: `hl.config()`

```lua
-- General settings
hl.config({
  general = {
    gaps_in = 8, gaps_out = 8,
    border_size = 0,
    col = { active_border = "0x89b4fa", inactive_border = "0x45475a" },
    layout = "dwindle",
  },
  decoration = {
    rounding = 8,
    blur = { enabled = true, size = 4, passes = 2 },
  },
  animations = { enabled = true },
  dwindle = { preserve_split = true, force_split = 2 },
  scrolling = { column_width = 0.5 },  -- Niri-like scrolling layout
  misc = { disable_hyprland_logo = true },
  cursor = { hide_on_key_press = true },
})
```

### Environment Variables: `hl.env()`

```lua
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("GDK_SCALE", "1")
```

**Important**: `cursor.theme` and `cursor.size` are NOT valid under `hl.config({ cursor = {...} })`.
Use `hl.env()` for cursor theme and size instead.

### Autostart: `o.launch_on_start()`

```lua
o.launch_on_start("awww-daemon")
o.launch_on_start("systemctl --user start podman-restart.service")
o.launch_on_start("bash -c 'sleep 2 && aether-sync.sh'")
```

### Animations: `hl.curve()` and `hl.animation()`

```lua
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 3.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
```

### Other APIs

```lua
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
o.window("app-id", { scroll_touchpad = 0.2 })
hl.exec("command string")
hl.dispatch("dispatcher args")
```

## Default File Structure

```
~/.config/hypr/
├── hyprland.lua       # Main config (bootstraps Omarchy, loads user files)
├── bindings.lua       # Keybinding overrides
├── input.lua          # Keyboard/mouse/touchpad overrides
├── looknfeel.lua      # Appearance overrides (gaps, rounding, animations)
├── autostart.lua      # Extra autostart processes
├── monitors.lua       # Monitor configuration
├── windows.lua        # Window rule overrides (user-created, not default)
└── hyprsunset.conf    # Night light config
```

## Omarchy Default Bindings

Loaded from `/usr/share/omarchy/default/hypr/bindings/`:
- `applications.lua` — Terminal, browser, file manager, tmux, herdr, obsidian, webapps
- `clipboard.lua` — Clipboard manager
- `media.lua` — Volume, brightness, keyboard backlight, media controls
- `tiling.lua` — Window management, workspaces, resize, groups, monitor scaling
- `utilities.lua` — Launcher, emoji, screenshot, capture, audio, bluetooth, display
- `voxtype.lua` — Voice-to-text

## Omarchy Default Apps (Window Rules)

Located at `/usr/share/omarchy/default/hypr/apps/*.lua`:
- `browser.lua` — Chromium-based and Firefox-based browser rules
- `terminals.lua` — Ghostty, kitty, foot, alacritty
- `system.lua` — System tools
- `hermes.lua` — Hermes agent HUD
- `1password.lua` — Password manager
- `jetbrains.lua` — IDE
- `steam.lua`, `retroarch.lua`, `geforce.lua` — Gaming
- `telegram.lua`, `localsend.lua`, `moonlight.lua` — Communication/remote

## Theming (Aether)

Aether is installed at `/usr/bin/aether` v4.29.8. Use `omarchy theme set <wallpaper>`
to extract colors from an image. Available themes at `/usr/share/omarchy/themes/`.

```bash
omarchy theme list           # List available themes
omarchy theme set <wallpaper> # Set theme from wallpaper
omarchy theme get-colors     # Get current colors as JSON
```

Colors available at `~/.cache/omarchy/colors.json`.
