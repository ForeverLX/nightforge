# Niri Migration Guide

## Why Niri?

**Problem with Sway:**
- Manual tiling became friction during multi-window AD attacks
- No built-in overview mode
- Window resizing disrupted focus during pivots

**Niri Advantages:**
- Scrolling layout (windows never resize)
- Built-in overview (visual workspace switcher)
- Per-monitor workspaces
- Better Wayland support

## Migration Steps

### 1. Install Niri
```bash
yay -S niri
```

### 2. Deploy Configs
```bash
mkdir -p ~/.config/niri
cp -r ~/Github/offsec-workstation/dotfiles/niri/* ~/.config/niri/

# Create monitor config from template
cp ~/.config/niri/includes/local.kdl.template ~/.config/niri/includes/local.kdl

# Edit for your monitors
nvim ~/.config/niri/includes/local.kdl
```

### 3. Validate
```bash
niri validate
```

### 4. Start Niri
```bash
# From display manager, select "Niri"
# Or from TTY:
niri-session
```

## Key Differences

| Feature | Sway | Niri |
|---------|------|------|
| Layout | Manual tiling | Scrolling |
| Overview | External (swayr) | Built-in |
| Workspaces | Global | Per-monitor |
| Window resize | Affects neighbors | Never affects |

## Keybind Changes

**Sway → Niri:**
- `Mod+D` → DMS Launcher (was dmenu)
- `Mod+Space` → Overview (was float)
- `Mod+Shift+Space` → Float (moved from Mod+Space)
- `Mod+Tab` → Overview (alternative)

## Troubleshooting

**Niri won't start:**
```bash
# Check logs
journalctl --user -u niri.service -n 50

# Validate config
niri validate
```

**Monitor config issues:**
```bash
# List outputs
niri msg outputs

# Edit local.kdl with correct names
nvim ~/.config/niri/includes/local.kdl
```
