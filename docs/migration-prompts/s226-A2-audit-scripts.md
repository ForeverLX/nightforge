# Task S226-A2: Audit scripts/ — Categorize All Scripts for Niri References

**Phase:** A (Pre-Migration Audit)
**Model:** Ornith-1.0-9B
**Harness:** Pi (interactive)
**Estimated context:** ~5K tokens

---

## Background

`scripts/` contains shell scripts and launchers that manage the NightForge desktop. Many reference Niri-specific commands (`niri msg`, `niri validate`), matugen theming, or quickshell IPC. Each script must be categorized as keep / adapt / discard.

## Instructions

For each script in `scripts/` and `scripts/harness/`, determine:

1. **Script name and purpose**
2. **Niri-specific calls** (e.g., `niri msg`, `niri validate`, `niri --version`)
3. **Matugen-specific calls** (e.g., `matugen image`, references to `colors.json`)
4. **Quickshell-specific IPC** (e.g., `/tmp/qs_widget_state`)
5. **Action** (keep / adapt / discard)
6. **If adapt**: which Niri/matugen calls need to be replaced with Hyprland/Aether equivalents

## Input: scripts/ Directory Structure

```
scripts/ (16 files)
├── apply-dotfiles.sh          — Stow-based dotfile deployer
├── backup-niri-config.sh      — Niri config backup launcher (thin → cmd/niri-backup)
├── cue-to-kdl.sh              — CUE → KDL generator launcher
├── cue-validate.sh            — CUE validation launcher
├── deploy.sh                  — Main deploy script (stow packages)
├── fidelity-check.sh          — Generated KDL vs source verification
├── focus-or-spawn.sh          — Smart window focus/spawn (uses niri msg)
├── matugen-sync.sh            — Wallpaper → colors → sync all configs
├── niri-outputs/main.go       — Niri output monitor (uses niri msg outputs)
├── niri-staging-validate.sh   — Full staging validation pipeline
├── open-control-center.sh
├── quickshell-toggle-daemon.sh — Quickshell widget IPC watcher
├── toggle-performance-mode.sh
├── wallpaper-picker.sh
├── wallpaper-rotate.sh
└── fidelity-check.sh

scripts/harness/ (subdirectory)
├── snapshot-config.sh — Snapshots config files for version control

scripts/audit/ (subdirectory)
├── package-audit.sh — Package inventory (references "Niri/Sway")

scripts/setup/ (subdirectory)
├── (various setup scripts)
```

## Niri References Found via grep

The following files contain `niri` or `matugen` references:

```
scripts/apply-dotfiles.sh:36:    "niri"
scripts/deploy.sh:27:for pkg in matugen rofi ghostty systemd niri; do
scripts/focus-or-spawn.sh:68:if ! pgrep -x niri
scripts/focus-or-spawn.sh:75:WINDOWS_JSON=$(niri msg --json windows
scripts/focus-or-spawn.sh:97:niri msg action focus-window --id "$FIRST_ID"
scripts/focus-or-spawn.sh:110:NEW_WINDOWS_JSON=$(niri msg --json windows
scripts/focus-or-spawn.sh:116:niri msg action move-window-to-workspace --id "$NEW_ID" "scratch"
scripts/matugen-sync.sh:290:# --- Niri Window Border Colors ---
scripts/matugen-sync.sh:293:    cat > "$HOME/.config/niri/includes/colors.kdl" << NIRI_EOF
scripts/quickshell-toggle-daemon.sh:3:# Usage: Run as background process (e.g., via niri spawn-at-startup)
scripts/harness/snapshot-config.sh:27:snapshot_file "${HOME}/.config/niri/config.kdl" "niri/config.kdl"
scripts/niri-outputs/main.go:30:raw, err := exec.Command("niri", "msg", "outputs").Output()
scripts/niri-outputs/main.go:154:cfg := fmt.Sprintf(`output "%s" { ... }`, ...)  # Niri config block
scripts/audit/package-audit.sh:116:"Window Manager (Niri/Sway)"
scripts/audit/package-audit.sh:132:pacman -Q | grep -E 'niri|sway|wlroots|wayland'
```

## Expected Output

A markdown table:

| Script | Niri Calls | Matugen Calls | Quickshell IPC | Action | If Adapt: Replacements Needed |

## Acceptance Criteria

- All 16 scripts in scripts/ categorized
- scripts/harness/snapshot-config.sh, scripts/audit/package-audit.sh, scripts/niri-outputs/main.go included
- At least 6 scripts marked "adapt" (must replace Niri/matugen calls)
- At least 3 scripts marked "discard" (Niri-only tooling)
- At least 5 scripts marked "keep as-is" (WM-agnostic)

## Rollback

No system changes — audit-only. No rollback needed.