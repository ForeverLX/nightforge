# Task S226-A4: Backup Current Configs & Create Snapshot

**Phase:** A (Pre-Migration Audit & Backup)
**Model:** Spark-X2.5-4B
**Harness:** Prime Agent (autonomous, long-running)
**Estimated context:** ~3K tokens

---

## Background

Before starting the Niri → Hyprland/Omarchy migration, all current configurations must be backed up. The NightForge toolchain already has a Go-based backup tool (`cmd/niri-backup/`) that creates a SHA-256-verified tarball of the Niri config. Additional backups needed for Hyprland configs (already partially migrated locally) and the full dotfiles tree.

## Instructions

Execute the following backup steps in order:

### Step 1: Run existing Niri backup tool
Build and run the backup tool:
```bash
cd ~/Projects/nightforge
scripts/backup-niri-config.sh --target ~/Backups/nightforge/pre-migration-S226

# Verify
scripts/backup-niri-config.sh --verify ~/Backups/nightforge/pre-migration-S226
```

**Expected:** Output should show `OK: backup checksums verify (N files).`

### Step 2: Backup local Hyprland config
The local Hyprland config already exists at `~/.config/hypr/`. Back it up:
```bash
mkdir -p ~/Backups/nightforge/hypr-local-S226
cp -a ~/.config/hypr/* ~/Backups/nightforge/hypr-local-S226/
```

### Step 3: Backup matugen-generated theme files
```bash
mkdir -p ~/Backups/nightforge/matugen-S226
cp -a ~/.config/matugen ~/.config/environment.d/98-matugen.conf ~/.config/fastfetch/config.jsonc ~/.config/waybar ~/.config/mako ~/.config/rofi ~/.config/kitty ~/.config/fuzzel ~/.config/gtk-3.0 ~/.config/gtk-4.0 ~/.config/qt6ct ~/.config/btop ~/.config/starship.toml 2>/dev/null || true
cp -a ~/.local/bin/matugen-sync.sh ~/Backups/nightforge/matugen-S226/ 2>/dev/null || true
cp -a ~/.local/bin/clipboard-picker.sh ~/.local/bin/wallpaper-rotate.sh ~/.local/bin/audio-switch.sh 2>/dev/null || true
```

### Step 4: Backup quickshell config
```bash
mkdir -p ~/Backups/nightforge/quickshell-S226
cp -a ~/.config/quickshell ~/Backups/nightforge/quickshell-S226/ 2>/dev/null || true
cp -a /tmp/qs_colors.json /tmp/qs_widget_state 2>/dev/null || true
```

### Step 5: Create a git snapshot
```bash
cd ~/Projects/nightforge
git stash list
git add -A
git commit -m "S226: Pre-migration snapshot before Niri → Omarchy migration

- Dotfiles: Niri config, matugen templates, quickshell QML
- Scripts: matugen-sync.sh, focus-or-spawn.sh, deploy.sh
- CUE: nightforge.niri schema + data
- Go tools: cue-to-kdl, fidelity-check, niri-staging-validate" --allow-empty
git tag S226-pre-migration-backup-$(date +%Y%m%d)
```

### Step 6: Verify all backups
```bash
echo "=== Niri backup ==="
ls -la ~/Backups/nightforge/pre-migration-S226/
scripts/backup-niri-config.sh --verify ~/Backups/nightforge/pre-migration-S226

echo "=== Hyprland backup ==="
ls -la ~/Backups/nightforge/hypr-local-S226/

echo "=== Git tag ==="
git tag -l 'S226-*'
git log --oneline -3
```

## Expected Output

```
OK: backup checksums verify (N files).
=== Niri backup ===
[niri-config-*.tar.gz, manifest.sha256]
=== Hyprland backup ===
[hyprland.lua, bindings.lua, input.lua, looknfeel.lua, autostart.lua, ...]
=== Git tag ===
S226-pre-migration-backup-YYYYMMDD
[commit hash] S226: Pre-migration snapshot...
```

## Acceptance Criteria

- Niri config backed up with verified SHA-256 checksums
- Local Hyprland config backed up (all .lua and .conf files)
- Matugen-generated theme files saved
- Quickshell config saved
- Git tag `S226-pre-migration-backup-YYYYMMDD` created
- All backup directories non-empty and listed

## Rollback

Use `git tag S226-pre-migration-backup-YYYYMMDD` to reset. Use tarball restore:
```bash
tar -xzf ~/Backups/nightforge/pre-migration-S226/niri-config-*.tar.gz -C ~/.config/
```