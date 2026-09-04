# Task S226-A3: Audit Go Services and CUE Schemas for Niri Dependencies

**Phase:** A (Pre-Migration Audit)
**Model:** Ornith-1.0-9B
**Harness:** Pi (interactive)
**Estimated context:** ~7K tokens

---

## Background

NightForge has a CUE-based config migration toolchain (5 Go commands in `cmd/`, shared `internal/nfutil/`, and a standalone `scripts/niri-outputs/main.go`). All currently target Niri KDL. Additionally, the TETHER harness daemon (`cmd/harnessd/`) and internal API (`internal/handler/layers.go`) contain Niri references. This audit identifies what must change vs. what can stay.

## Instructions

1. **For each Go file** in `cmd/` and `internal/`, list all Niri-specific code:
   - Package name (`package niri`)
   - Binary names (`niri`, `niri validate`)
   - File paths (`dotfiles/niri/...`, `build/niri-staging/`)
   - Module name (`nightforge.niri`)

2. **For the CUE schema files**, identify what's Niri-specific:
   - `cue/nightforge.cue` — data (spawns, binds, window rules)
   - `cue/schema.cue` — type definitions
   - `cue/cue.mod/module.cue` — module declaration

3. **For harnessd/internal**:
   - Check `cmd/harnessd/` — does it use Niri IPC?
   - Check `internal/handler/layers.go` — line 19 references "Niri" in a description string

4. **Classify each tool**: keep / adapt / discard

## Input: Go Files with Niri References

### cmd/cue-to-kdl/main.go (328 lines)
- Package: `main`
- Generates Niri KDL from CUE config
- Reads from: `dotfiles/niri/.config/niri/includes/` (input.kdl, compositor.kdl, colors.kdl)
- Writes to: `build/niri-staging/` (config.kdl, includes/keybinds.kdl, includes/window-rules.kdl)
- Output format: Niri KDL syntax

### cmd/cue-validate/main.go (75 lines)
- Validates CUE format and schema
- References "nightforge.niri" in output
- Uses `internal/nfutil.ExportConfig`

### cmd/fidelity-check/main.go (594 lines)
- Compares generated KDL vs source KDL for semantic equality
- Parses Niri-specific KDL syntax (binds { }, window-rule { }, spawn-at-startup)
- Reads from: `dotfiles/niri/.config/niri/includes/keybinds.kdl` and `window-rules.kdl`

### cmd/niri-staging-validate/main.go (137 lines)
- Pipeline: cue-to-kdl → fidelity-check → `niri validate`
- Calls `exec.Command("niri", "validate", ...)`
- References `build/niri-staging/`

### cmd/niri-backup/main.go (289 lines)
- Tars `dotfiles/niri/.config/niri/` to backup
- SHA-256 manifest verification
- Default target: `~/Backups/nightforge/pre-cue-migration/`

### internal/nfutil/nfutil.go (118 lines)
- Comment references "package niri" (line 18)
- `ExportConfig` runs `cue export` in `cue/` directory

### internal/handler/layers.go (line 19)
- Contains: `{ID: "L1", Name: "Hardware/Infra", Status: "complete", Description: "Arch Linux, Niri, NightForge"}`
- Niri reference is just in a description string, not functional

### scripts/niri-outputs/main.go (164 lines)
- Standalone tool: calls `niri msg outputs` to get monitor info
- Generates Niri `output "X" { ... }` config block
- Also exists at `niri-modifications/outputs/main.go` (duplicate)

## CUE Schema Files

### cue/cue.mod/module.cue
```
module: "nightforge.niri"
language: { version: "v0.17.1" }
```

### cue/nightforge.cue (181 lines)
- `package niri`
- Contains: `config` with `spawnAtStartup` (8 items), `binds` (90 items), `windowRules` (35 items)
- All Niri-specific data structures

### cue/schema.cue (85 lines)
- Defines `#Config`, `#Spawn`, `#Bind`, `#Action`, `#BuiltinAction`, `#SpawnAction`, `#WindowRule`, `#Width`
- All Niri-specific type names and field names

## Expected Output

A markdown document with:

1. **Summary table:**

| Component | Niri-Specific? | Action | Notes |
|-----------|----------------|--------|-------|
| cmd/cue-to-kdl | Yes | Rewrite as hypr-to-lua | Generates KDL → must generate Lua |
| cmd/cue-validate | Partial | Rename + update | Just validation, change module name |
| cmd/fidelity-check | Yes | Rewrite | Parses Niri KDL, needs Hyprland Lua parser |
| cmd/niri-staging-validate | Yes | Rewrite as hypr-staging-validate | Calls `niri validate` → `hyprland --validate` |
| cmd/niri-backup | Yes | Rename as hypr-backup | Backs up dotfiles/niri/ → dotfiles/hypr/ |
| internal/nfutil | Partial | Update | Change CUE export target, update Config struct |
| scripts/niri-outputs | Yes | Rewrite | `niri msg outputs` → `hyprctl monitors -j` |
| cmd/harnessd | No | Keep | No Niri IPC, uses /proc and nvidia-smi |
| internal/handler/layers.go | No | Keep/fix | Only a description string needs updating |

2. **Migration priority** (1=critical, 5=optional):
   - cue-to-kdl + fidelity-check: **Priority 1** (core auth pipeline broken without these)
   - niri-staging-validate: **Priority 1** (gating step)
   - niri-backup: **Priority 2** (backup before changes)
   - niri-outputs: **Priority 3** (monitor config)
   - cue-validate: **Priority 1** (pre-req for schema migration)
   - nfutil: **Priority 1** (shared dependency)

3. **Files-to-delete list**:
   - `cmd/niri-backup/` (rename to cmd/hypr-backup)
   - `cmd/niri-staging-validate/` (rename to cmd/hypr-staging-validate)
   - `scripts/backup-niri-config.sh` (rename to backup-hypr-config.sh)
   - `scripts/niri-staging-validate.sh` (rename to hypr-staging-validate.sh)
   - `niri-modifications/` (entire directory — duplicate of scripts/niri-outputs)

## Acceptance Criteria

- All 5 cmd/ directories inventoried with Niri references identified
- internal/nfutil/nfutil.go audited for CUE schema dependencies
- cmd/harnessd/ confirmed as Niri-free
- internal/handler/layers.go Niri reference noted as cosmetic
- scripts/niri-outputs/main.go audited for Niri IPC dependencies
- Priority order established for Go tool migration
- File deletion/renaming list created

## Rollback

Audit-only — no system changes. No rollback needed.