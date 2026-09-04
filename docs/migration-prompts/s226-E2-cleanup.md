# Task S226-E2: Cleanup — Remove Niri/matugen/quickshell Artifacts

**Phase:** E (Validation & Cleanup)
**Model:** Spark-X2.5-4B (code generation, multi-file changes)
**Harness:** Pi (interactive)
**Estimated context:** ~5K tokens
**Priority:** 2
**Depends on:** E1 (all tests must pass before cleanup)

---

## Background

After the migration is validated, all Niri/matugen/quickshell artifacts must be removed from the NightForge repository and local system. The handoff Phase E.4 specifies: "Remove Niri, matugen, quickshell, kitty configs."

## Audit of Niri/matugen/quickshell References

Based on Tasks A2 and A3, the following items must be removed or updated:

### Repository files to remove:
1. `dotfiles/niri/` — entire directory (Niri config KDL files, includes, scripts)
2. `dotfiles/matugen/` — entire directory (matugen config + templates)
3. `dotfiles/kitty/` — legacy terminal (Ghostty is the replacement)
4. `modules/niri/` — entire directory (Niri module: install.sh, packages.list, README.md)
5. `niri-modifications/` — entire directory (outputs/main.go, scripts/, README.md, local.kdl.example)
6. `scripts/niri-outputs/main.go` — already being replaced by Task C8
7. `docs/NIRI-MIGRATION.md` — Sway → Niri migration doc (outdated)
8. `docs/NIGHTFORGE-SHELL-MIGRATION.md` — DMS → Quickshell+Matugen migration doc (outdated)

### Repository files to update:
9. `scripts/apply-dotfiles.sh` — remove "niri" from PACKAGES (Task D2)
10. `scripts/deploy.sh` — remove niri/matugen from stow list (Task D2)
11. `scripts/harness/snapshot-config.sh` — change niri→hypr snapshot (Task D2)
12. `internal/handler/layers.go` line 19 — "Arch Linux, Niri, NightForge" → "Arch Linux, Hyprland/Omarchy, NightForge"
13. `docs/DECISIONS.md` — check for Niri references
14. `README.md` — check for Niri references
15. `AGENTS.md` — check for Niri references

### CUE module to update:
16. `cue/cue.mod/module.cue` — already updated in Task C6 (but verify)

### Old cmd/ directories to remove:
17. `cmd/niri-backup/` — replaced by cmd/hypr-backup (Task C7)
18. `cmd/niri-staging-validate/` — replaced by cmd/hypr-staging-validate (Task C7)

### Old launcher scripts to remove:
19. `scripts/backup-niri-config.sh` — replaced by scripts/backup-hypr-config.sh (Task C7)
20. `scripts/cue-to-kdl.sh` — replaced by scripts/hypr-to-lua.sh (Task C7)
21. `scripts/cue-validate.sh` — replaced by scripts/hypr-valid.sh (Task C7)
22. `scripts/fidelity-check.sh` — replaced by scripts/hypr-fidelity-check.sh (Task C7)
23. `scripts/niri-staging-validate.sh` — replaced by scripts/hypr-staging-validate.sh (Task C7)

### Local system files to remove:
24. `~/.config/niri/` — if still present (local Niri config)
25. `~/.config/matugen/` — if still present (local matugen config)
26. `~/.config/kitty/` — if still present (legacy terminal)
27. `~/.config/quickshell/` — only if Waybar fully replaces it
28. `~/.local/bin/matugen-sync.sh` — local copy of matugen-sync.sh
29. `~/.local/bin/focus-or-spawn.sh` — Niri IPC version (replaced by Task C8)
30. `~/.local/share/matugen/` — matugen backup directory

### Systemd services to remove:
31. Any `matugen-sync.service` user systemd unit
32. Any Niri session files in `~/.local/share/wayland-sessions/` or `/usr/share/wayland-sessions/`

## Instructions

### Step 1: Repository file cleanup
Remove all files listed in section 1-23 above. Use `git rm` for tracked files:

```bash
cd ~/Projects/nightforge
# Remove directories
rm -rf dotfiles/niri/ dotfiles/matugen/ dotfiles/kitty/ modules/niri/ niri-modifications/
# Remove old cmd dirs (only if Task C7 succeeded)
rm -rf cmd/niri-backup/ cmd/niri-staging-validate/
# Remove old scripts (only if Task C7 succeeded)
rm -f scripts/backup-niri-config.sh scripts/cue-to-kdl.sh scripts/cue-validate.sh scripts/fidelity-check.sh scripts/niri-staging-validate.sh
# Remove outdated docs
rm -f docs/NIRI-MIGRATION.md docs/NIGHTFORGE-SHELL-MIGRATION.md
```

### Step 2: Update remaining references
```bash
# Find and fix any remaining Niri/matugen references
grep -rn "niri\|matugen" --include="*.go" --include="*.md" --include="*.sh" --include="*.lua" .
# Update each reference individually
```

### Step 3: Local system cleanup
```bash
# Only remove if migration is confirmed working
rm -rf ~/.config/niri/~/.config/matugen/ ~/.config/kitty/
rm -f ~/.local/bin/matugen-sync.sh ~/.local/bin/focus-or-spawn.sh
rm -rf ~/.local/share/matugen/
# Remove systemd services
systemctl --user stop matugen-sync.service 2>/dev/null || true
systemctl --user disable matugen-sync.service 2>/dev/null || true
rm -f ~/.config/systemd/user/matugen-sync.service
systemctl --user daemon-reload
```

### Step 4: Verify
```bash
# No Niri/matugen references remain
grep -rn "niri\|matugen" --include="*.go" --include="*.md" --include="*.sh" --include="*.lua" --include="*.qml" . | wc -l
# Should output 0 (or only intentional references in migration docs)

go build ./cmd/...
go vet ./...
bash -n scripts/*.sh

git status --short
```

## Expected Output

1. Git status showing all removed files as deleted
2. Remaining Niri/matugen references (should be 0 in code files)
3. `go build ./cmd/...` succeeds
4. `go vet ./...` succeeds
5. All shell scripts pass `bash -n`

## Acceptance Criteria

- All Niri/matugen/quickshell/kitty files and directories removed from repo
- No `niri` or `matugen` references remain in any `.go`, `.sh`, `.lua`, `.qml`, or `.md` file
- `go build ./cmd/...` succeeds with no errors
- `go vet ./...` succeeds with no errors
- `bash -n scripts/*.sh` passes on all remaining scripts
- Local system cleaned of Niri/matugen/kitty configs
- Old systemd services removed
- Git commit created with message: "S226: Remove Niri/matugen/quickshell artifacts after Omarchy migration"

## Rollback

```bash
git reset --hard HEAD~1  # revert cleanup commit
# Or restore from the pre-migration backup tag
git reset --hard S226-pre-migration-backup-YYYYMMDD
```
