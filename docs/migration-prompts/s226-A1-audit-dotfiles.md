# Task S226-A1: Audit dotfiles/ — Inventory All Directories

**Phase:** A (Pre-Migration Audit)
**Model:** Ornith-1.0-9B
**Harness:** Pi (interactive)
**Estimated context:** ~4K tokens

---

## Background

NightForge stores all desktop environment config in `dotfiles/` using GNU Stow. The repo currently has a mix of Niri-specific, matugen-specific, quickshell-specific, and neutral (WM-agnostic) directories. Before migration to Omarchy/Hyprland, each directory must be categorized.

## Instructions

Read the `dotfiles/` directory and for **each** subdirectory, determine:

1. **What it configures** (e.g., terminal, shell prompt, window manager)
2. **Whether it's Niri-specific** (only works with Niri compositor)
3. **Whether it's matugen-specific** (depends on matugen color format)
4. **Whether it's quickshell-specific** (Qt/QML files only used by quickshell)
5. **Whether it's Omarchy-compatible** (works as-is with Hyprland/Omarchy)
6. **Action needed** (keep as-is / adapt / discard)

## Input: dotfiles/ Directory Listing (27 directories)

```
btop/          fish/        fontconfig/   fuzzel/       ghostty/
gtk-3.0/       gtk-4.0/      gtklock/      kitty/        matugen/
niri/          nvim/         opencode/     operator-terminal/
qt6ct/         quickshell/   rofi/         satty/        scripts/
ssh-agent/     starship/     swaylock/     swayosd/      systemd/
tmux/          zsh/
```

## Known Niri-specific directories

- `niri/` — Full Niri config (config.kdl, includes/, scripts/)
- `matugen/` — Matugen color generation configs and templates

## Known quickshell-specific directories

- `quickshell/` — Full quickshell shell (QML modules, services, scripts)

## Known kitty (legacy terminal)

- `kitty/` — Legacy terminal, NightForge already uses Ghostty

## Expected Output

A markdown table with one row per dotfile directory:

| Directory | Configures | Niri-specific? | Matugen-specific? | Quickshell-specific? | Omarchy-compatible? | Action |

## Acceptance Criteria

- All 27 directories listed in the table
- Each directory has a clear categorization
- At least 3 directories marked as "discard" (e.g., niri, matugen, kitty)
- At least 8 directories marked as "keep as-is" (WM-agnostic tools)
- At least 2 directories marked as "adapt" (quickshell → Waybar, etc.)

## Rollback

No system changes — this is an audit-only task. No rollback needed.