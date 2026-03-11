# Screenshot System Documentation

## Overview
Wayland-native screenshot system using grim + slurp + swappy.

**6 screenshot modes** optimized for NuPhy Air75 (no Print key).

## Quick Reference

| Keybind | Mode | Use Case |
|---------|------|----------|
| `Mod+S` | area-pip | 80% - Engagement docs with annotation |
| `Mod+Shift+S` | area-clipboard | 15% - Quick share to Slack/Discord |
| `Mod+Ctrl+S` | area-edit | Detailed annotation (fullscreen) |
| `Mod+Alt+S` | screen | Full screen capture |
| `Mod+Alt+Shift+S` | screen-clipboard | Screen share |
| `Mod+Alt+W` | window | Single window only |

## Workflow Examples

### Engagement Documentation (area-pip)
```
1. Exploit successful access
2. Press Mod+S
3. Select region (terminal output)
4. Swappy opens (floating window)
5. Add arrow pointing to creds
6. Add text: "Domain Admin credentials"
7. Click Save
8. Screenshot in ~/Pictures/Screenshots/
```

### Quick Team Share (area-clipboard)
```
1. Press Mod+Shift+S
2. Select region
3. Paste in Slack (Ctrl+V)
```

## Tools

**grim** - Screenshot capture
**slurp** - Region selector
**swappy** - Annotation editor
**hyprpicker** - Color picker (Mod+Shift+P)

## Configuration

**Script:** `~/.config/niri/scripts/screenshot.sh`
**Swappy Config:** `~/.config/swappy/config`
**Save Directory:** `~/Pictures/Screenshots/`

## Swappy Tips

**Tools:**
- Arrow: Draw arrows
- Line: Draw lines
- Rectangle/Circle: Shapes
- Text: Add text annotations
- Blur: Sanitize sensitive info (IPs, hostnames)

**Keybinds:**
- `Ctrl+S` - Save
- `Ctrl+C` - Copy to clipboard
- `Escape` - Close without saving
- `Ctrl+Z` - Undo
- `Ctrl+Y` - Redo

## OPSEC

**Before sharing screenshots:**
1. Check for IPs/hostnames
2. Blur sensitive terminal output
3. Remove client-identifiable info
4. Review file metadata

**Sanitization workflow:**
```bash
# Open screenshot in swappy
swappy -f ~/Pictures/Screenshots/screenshot_20260309_123456.png

# Use blur tool on sensitive regions
# Save sanitized version
```
