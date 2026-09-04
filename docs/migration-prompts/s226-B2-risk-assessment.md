# Task S226-B2: Risk Assessment — Niri → Omarchy Migration

**Phase:** B (Omarchy Setup — Planning)
**Model:** Ornith-1.0-9B (systematic analysis)
**Harness:** Pi (interactive)
**Estimated context:** ~4K tokens
**Priority:** 1 (must complete before migration begins)
**Depends on:** A1, A2, A3 (audit results)

---

## Background

The original migration prompt (Phase 5) asks for a risk assessment. Based on the audit tasks (A1-A3), we now know all the Niri-specific components. This task identifies risks and their mitigations before any changes are made.

## Instructions

Review the audit findings from Tasks A1-A3 and the codebase analysis, then identify:

1. **What could go wrong** in each migration category
2. **Likelihood** (high/medium/low)
3. **Impact** (high/medium/low)
4. **Mitigation** (how to prevent or recover)
5. **Rollback path** (how to restore if needed)

## Risk Categories

### 1. Keybinding Loss / Unmappable Actions
- **Risk**: Some Niri keybindings have no Hyprland equivalent (e.g., `toggle-column-tabbed-display`, `consume-or-expel-window-left`)
- **Likelihood**: Medium
- **Impact**: High (daily workflow disruption)
- **Mitigation**: Document removed actions with comments; provide alternative Hyprland dispatchers where possible
- **Rollback**: Keep original keybinds.kdl backup

### 2. Color Pipeline Breakage
- **Risk**: Aether color schema differs from matugen's; some output targets may not get their colors
- **Likelihood**: Medium
- **Impact**: High (visual regression across all apps)
- **Mitigation**: Verify color field mapping for all 15+ targets; test one app at a time
- **Rollback**: Keep matugen-sync.sh, revert to matugen if Aether fails

### 3. CUE Toolchain Breakage
- **Risk**: Rewriting 5 Go tools + nfutil could introduce bugs; fidelity check may not pass
- **Likelihood**: High
- **Impact**: High (config generation pipeline broken)
- **Mitigation**: Port tools incrementally (C6 before C7); run fidelity checks after each
- **Rollback**: Git checkout of cmd/ and internal/ before migration

### 4. IPC Compatibility
- **Risk**: Scripts using `niri msg` (focus-or-spawn.sh, niri-outputs, workspaces.sh) may not fully translate to `hyprctl`
- **Likelihood**: Medium
- **Impact**: Medium (window management automation breaks)
- **Mitigation**: Test each script after porting; Hyprland `hyprctl` has different JSON schema
- **Rollback**: Keep original scripts with .backup extension

### 5. Panel (Quickshell → Waybar) Feature Loss
- **Risk**: Waybar doesn't natively support some quickshell widgets (engagement context, MPD controls, performance mode toggle)
- **Likelihood**: Medium
- **Impact**: Medium (reduced status visibility)
- **Mitigation**: Implement custom Waybar scripts for each missing indicator
- **Rollback**: Keep quickshell config if Waybar migration fails (ARCHITECTURE.md notes quickshell *can* work on Hyprland)

### 6. Local Config Conflicts
- **Risk**: Local `~/.config/hypr/` already has Omarchy defaults; migration may conflict
- **Likelihood**: Low
- **Impact**: Medium (can't start Hyprland)
- **Mitigation**: Always test with `Hyprland --dry-run` or backup first
- **Rollback**: Restore from local Hyprland backup (Task A4 backup)

### 7. Git Module References
- **Risk**: `internal/handler/layers.go` line 19 hardcodes "Niri" in a description string; CUE module name is `nightforge.niri`
- **Likelihood**: High (easy to miss)
- **Impact**: Low (cosmetic, but CI may check)
- **Mitigation**: Grep for remaining references after migration
- **Rollback**: N/A (simple string replacement)

## Expected Output

A markdown file at `~/Projects/nightforge/docs/migration-prompts/s226-B2-risk-assessment.md` containing:

1. The 7 risk categories above with likelihood/impact/mitigation
2. **Risk priority matrix** (table sorted by likelihood × impact)
3. **Critical path dependencies** (which tasks must succeed before others can proceed)
4. **Go/no-go checklist** (items that MUST pass before proceeding to next phase)

## Acceptance Criteria

- All 7 risk categories documented with likelihood, impact, mitigation, rollback
- Risk priority matrix created (sorted by severity)
- Critical path dependencies identified (at least 5 dependencies)
- Go/no-go checklist with at least 8 items
- File created at the specified path

## Rollback

No changes — risk assessment is documentation only.