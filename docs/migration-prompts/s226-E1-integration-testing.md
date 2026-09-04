# Task S226-E1: Integration Testing — Verify Migrated Components

**Phase:** E (Validation & Cleanup)
**Model:** Ornith-1.0-9B (code review, debugging)
**Harness:** OMP with Ornith as advisor (second-opinion model watches every turn)
**Estimated context:** ~5K tokens
**Priority:** 1 (validation before cleanup)
**Depends on:** C1, C2, C3, C4, C5, C6, C7, C8, D1, D2

---

## Background

After all migration tasks are complete, a full integration test must verify that the Hyprland/Omarchy desktop works end-to-end. The original handoff Phase E.1-3 lists specific tests. This task executes those tests using the local model for debugging and verification.

## Test Environment

- **Compositor**: Hyprland (Omarchy default)
- **Shell**: Omarchy shell (Quickshell on Hyprland) or Waybar
- **Theming**: Aether (omarchy theme set)
- **Models available**: Spark-X2.5-4B (localhost:8080), Ornith-1.0-9B, LFM2.5-2.6B

## Test Checklist

### E1.1: Keybindings (10 tests)
Test each category of keybinding from `bindings.lua`:

| Test | Key | Expected Behavior | Status |
|------|-----|-------------------|--------|
| 1 | Super+Return | Ghostty opens | |
| 2 | Super+D | Fuzzel launcher opens | |
| 3 | Mod+Q | Active window closes | |
| 4 | Mod+Space | Overview toggles (or note: no overview plugin) | |
| 5 | Mod+Shift+Space | Window floats/unfloats | |
| 6 | Mod+1-5 | Switch to workspace 1-5 | |
| 7 | Mod+Shift+1-5 | Move window to workspace | |
| 8 | Mod+H/J/K/L | Focus moves left/down/up/right | |
| 9 | Mod+Ctrl+H/L | Window resizes horizontally | |
| 10 | Mod+Alt+Q | Compositor quits | |
| 11 | XF86AudioRaiseVolume | Volume increases via SwayOSD | |
| 12 | Print | Screenshot taken (grim/satty) | |
| 13 | Mod+Alt+R | Wallpaper rotates + Aether sync | |
| 14 | Mod+Shift+G | Ghostty opens engagement context | |
| 15 | Mod+Shift+T | Ghostty opens podman status | |

### E1.2: Theming (5 tests)
After running `aether-sync.sh <wallpaper>`:

| Test | Component | Expected | Status |
|------|-----------|----------|--------|
| 1 | Ghostty | Colors updated in `~/.config/ghostty/config` | |
| 2 | Waybar/Quickshell | Colors match Aether palette | |
| 3 | GTK apps | Theme colors applied | |
| 4 | Starship | Prompt colors updated | |
| 5 | Mako/swayosd | Notification/OSD colors match | |

### E1.3: Panel (3 tests)
| Test | Component | Expected | Status |
|------|-----------|----------|--------|
| 1 | Workspaces | Shows 5 workspace buttons, active highlighted | |
| 2 | Clock | Shows current time, updates every second | |
| 3 | Status indicators | MPD, Podman, VPN, battery all show correct state | |

### E1.4: Terminal + Editor (2 tests)
| Test | Component | Expected | Status |
|------|-----------|----------|--------|
| 1 | Ghostty | Launches, uses matugen-derived colors | |
| 2 | Neovim | Theme works, no errors on startup | |

### E1.5: CUE Tooling (3 tests)
| Test | Command | Expected | Status |
|------|---------|----------|--------|
| 1 | `go build ./cmd/...` | All tools compile | |
| 2 | `go vet ./...` | No errors | |
| 3 | `scripts/hypr-staging-validate.sh` | CUE → Lua generation, fidelity check, hyprland validate | |

### E1.6: Go Service (1 test)
| Test | Command | Expected | Status |
|------|---------|----------|--------|
| 1 | `go build ./cmd/harnessd/` && `./harnessd` | TETHER dashboard serves on 127.0.0.1:9191 | |

## Instructions

1. Do NOT test while Niri is still running (conflict). Use Hyprland only.
2. For each test, record the result (PASS/FAIL) in the table above.
3. If a test fails, diagnose and attempt a fix:
   - Check `journalctl -e -u display-manager` for compositor errors
   - Check `waybar` logs: `journalctl --user -u waybar -f`
   - Check Hyprland logs: `~/.local/state/hypr/hyprlandd.log`
4. For each failure, note:
   - What failed
   - Root cause
   - Fix applied
   - Whether fix was verified

## Expected Output

A markdown file at `~/Projects/nightforge/docs/migration-prompts/s226-E1-test-results.md` containing:

1. Completed test tables with PASS/FAIL for each test
2. Failure analysis section (if any tests failed):
   - Bug description
   - Root cause
   - Fix applied
   - Verification
3. Summary: total tests, passed, failed, pass rate

## Acceptance Criteria

- All E1.1 keybinding tests pass (or are documented as "removed/unavailable")
- All E1.2 theming tests pass (colors applied to all targets)
- All E1.3 panel tests pass (workspaces, clock, status indicators work)
- All E1.4 terminal + editor tests pass
- All E1.5 CUE tooling tests pass (build, vet, staging validation)
- All E1.6 Go service tests pass
- Test results file created with complete tables
- Any failures have root cause analysis and attempted fixes

## Rollback

If tests reveal critical failures that cannot be fixed, rollback to the backup tag:
```bash
git reset --hard S226-pre-migration-backup-YYYYMMDD
```