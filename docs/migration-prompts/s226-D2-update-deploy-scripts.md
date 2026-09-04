# Task S226-D2: Update Deployment & Snapshot Scripts

**Phase:** D (Service Migration)
**Model:** LFM2.5-2.6B (quick edits — simple string replacements)
**Harness:** Pi one-shot mode (`-p`)
**Estimated context:** ~8K tokens
**Priority:** 2

---

## Background

Three scripts reference Niri/matugen/quickshell packages that must be updated for the Hyprland/Omarchy migration:

1. `scripts/apply-dotfiles.sh` — stow package list includes "niri"
2. `scripts/deploy.sh` — stow package list includes "matugen" and "niri"
3. `scripts/harness/snapshot-config.sh` — snapshots `~/.config/niri/config.kdl`

Additionally:
- `scripts/quickshell-toggle-daemon.sh` — comment mentions "niri spawn-at-startup"
- `dotfiles/niri/.config/niri/scripts/keys.sh` — referenced in keybindings but needs path update

## Input: scripts/apply-dotfiles.sh (57 lines — key section)

```bash
#!/bin/bash
# apply-dotfiles.sh - Deploy dotfiles using GNU Stow
set -euo pipefail

# ...

# List of packages to stow
PACKAGES=(
    "niri"          # ← REMOVE: replaced by Hyprland/Omarchy
    "ghostty"
    "tmux"
    "swappy"
    "operator-terminal"
    "zsh"
    "starship"
    "nvim"
)
```

## Input: scripts/deploy.sh (39 lines — full)

```bash
#!/bin/bash
set -euo pipefail
set +e

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# Remove old quickshell files that block stow
rm -f ~/.config/quickshell/main.qml

# Remove conflicting regular files
for f in ~/.config/ghostty/config ~/.config/btop/btop.conf; do
    if [[ -f "$f" && ! -L "$f" ]]; then
        rm -f "$f"
        echo "[*] Removed conflicting file: $f"
    fi
done

set -euo pipefail

# Stow all dotfiles packages
for pkg in matugen rofi ghostty systemd niri; do
  if [[ -d "$REPO/dotfiles/$pkg" ]]; then
    echo "[*] Stowing $pkg..."
    stow -d "$REPO/dotfiles" -t ~ "$pkg"
  fi
done

# Copy quickshell (Quickshell resolves symlinks, breaking relative imports)
echo "[*] Copying quickshell..."
mkdir -p ~/.config/quickshell
rsync -av --delete "$REPO/dotfiles/quickshell/.config/quickshell/" ~/.config/quickshell/

echo "[+] Deploy complete. Run: quickshell &"
```

## Input: scripts/harness/snapshot-config.sh (55 lines — key section)

```bash
snapshot_file "${HOME}/.config/niri/config.kdl" "niri/config.kdl"
```

## Input: scripts/quickshell-toggle-daemon.sh (37 lines — key line)

```bash
# Usage: Run as background process (e.g., via niri spawn-at-startup)
```

## Input: dotfiles/quickshell/.config/quickshell/main.qml

```qml
// Requires: quickshell, matugen, niri
```

## Expected Changes

### 1. scripts/apply-dotfiles.sh
- Remove `"niri"` from PACKAGES array
- Add `"hyprland"` and `"waybar"` to PACKAGES array
- Keep: ghostty, tmux, swappy, operator-terminal, zsh, starship, nvim

### 2. scripts/deploy.sh
- Change `for pkg in matugen rofi ghostty systemd niri` → `for pkg in omarchy rofi ghostty systemd hyprland`
- Remove `rm -f ~/.config/quickshell/main.qml`
- Remove `rsync` of quickshell → replace with stow or copy of waybar
- Update final message: `Run: quickshell &` → `Run: systemctl --user restart waybar`
- Add hyprland config stow

### 3. scripts/harness/snapshot-config.sh
- Change `"${HOME}/.config/niri/config.kdl"` → `"${HOME}/.config/hypr/hyprland.lua"`
- Change `"niri/config.kdl"` → `"hypr/hyprland.lua"`

### 4. scripts/quickshell-toggle-daemon.sh
- Update comment: `niri spawn-at-startup` → `Hyprland autostart`

### 5. dotfiles/quickshell/.config/quickshell/main.qml
- Update comment: `Requires: quickshell, matugen, niri` → `Requires: quickshell, aether, hyprland`

### 6. scripts/focus-or-spawn.sh
- Update keybinding references: `~/.config/niri/scripts/` → `~/.local/bin/`

### 7. dotfiles/niri/.config/niri/includes/keybinds.kdl
- Update script paths: `~/.config/niri/scripts/` → `~/.config/hypr/scripts/` (for Niri-only scripts being removed)
- Actually, this file is the Niri source — it should not be modified here. The Hyprland keybindings are in `~/.config/hypr/bindings.lua` (Task C1).

## Acceptance Criteria

- `apply-dotfiles.sh`: PACKAGES array has no `niri`, includes `hyprland` and `waybar`
- `deploy.sh`: package list updated, quickshell references removed, waybar references added
- `snapshot-config.sh`: snapshots Hyprland config instead of Niri
- `quickshell-toggle-daemon.sh`: comment updated
- `main.qml`: comment updated
- `bash -n` passes on all 4 modified shell scripts
- No `niri` or `matugen` references in the 4 modified files (except in comments explaining the migration)

## Rollback

```bash
git checkout -- scripts/apply-dotfiles.sh scripts/deploy.sh scripts/harness/snapshot-config.sh scripts/quickshell-toggle-daemon.sh dotfiles/quickshell/.config/quickshell/main.qml
```