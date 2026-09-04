# Task S226-C7: Migrate Go CUE Tools Niri → Hyprland

**Phase:** C (Config Migration)
**Model:** Ornith-1.0-9B (multi-file refactoring, needs consistency)
**Harness:** Prime Agent (autonomous — touches 7+ files, must stay consistent)
**Estimated context:** ~18K tokens
**Priority:** 1 (blocking CUE migration pipeline)
**Depends on:** C6 (CUE schemas must be updated first)

---

## Background

The Go toolchain (`cmd/` + `internal/nfutil`) generates, validates, and backs up Niri KDL config. All 5 commands need to be ported from Niri to Hyprland:

| Current | New Name | Key Changes |
|---------|----------|-------------|
| `cmd/cue-to-kdl/` | `cmd/hypr-to-lua/` | KDL → Lua rendering, paths → hypr |
| `cmd/cue-validate/` | `cmd/hypr-validate/` | Module name, output text |
| `cmd/fidelity-check/` | `cmd/hypr-fidelity-check/` | KDL parser → Lua parser |
| `cmd/niri-staging-validate/` | `cmd/hypr-staging-validate/` | `niri validate` → `hyprland --validate` |
| `cmd/niri-backup/` | `cmd/hypr-backup/` | Backup source → dotfiles/hypr/ |

Plus shared `internal/nfutil/nfutil.go` (118 lines) and launcher scripts in `scripts/`.

## Input: internal/nfutil/nfutil.go (118 lines — full)

Key structures to update:
- Comment line 18: "package niri" → "package hypr"
- `Config` struct: field names stay (SpawnAtStartup, Binds, WindowRules) — the CUE field names are camelCase in JSON
- `Bind.Action` struct: `Kind` field still "spawn"/"builtin", but builtin names are now Hyprland dispatchers
- `Rule` struct: field names like `OpenFloating` → `Float`, `OpenFullscreen` → `Fullscreen`, `DefaultColumnWidth` → `Width`, etc. — BUT the CUE JSON field names are lowercase camelCase. If CUE schema uses `float: true` then JSON has `"float": true`, and Go struct needs `Float *bool json:"float"`.
- `ExportConfig` function (line 102-118): runs `cue export` — no change needed if CUE module is updated

## Input: cue-to-kdl → hypr-to-lua (328 lines — key changes needed)

The current tool generates Niri KDL:
```go
// Line 272: cfg, err := nfutil.ExportConfig(root)  // reads cue/nightforge.cue
// Lines 283-288: copies static includes from dotfiles/niri/.config/niri/includes/
// Lines 290-295: writes keybinds.kdl using renderKeybinds()
// Lines 296-300: writes window-rules.kdl using renderWindowRules()
// Lines 298-310: writes config.kdl with spawn-at-startup + includes
```

Changes needed:
1. Output directory: `build/niri-staging/` → `build/hypr-staging/`
2. Include source: `dotfiles/niri/.config/niri/includes/` → `dotfiles/hypr/.config/hypr/includes/`
3. Output file extensions: `.kdl` → `.lua`
4. Keybinds: render as Lua `o.bind()` calls instead of KDL `binds { }` blocks
5. Window rules: render as Lua `o.window()` calls instead of KDL `window-rule { }` blocks
6. Spawns: render as `o.launch_on_start()` instead of `spawn-at-startup`
7. Config: no `includes` in Lua (Hyprland uses `require()` or `dofile()`)

## Input: fidelity-check → hypr-fidelity-check (594 lines — key changes needed)

The current tool parses Niri KDL to canonical forms and compares:
```go
// Line 130-136: readSource(root, rel) reads from dotfiles/niri/.config/niri/
// Line 139-152: srcSpawns() parses config.kdl spawn-at-startup lines
// Line 201-270: srcBinds() parses binds { } block from keybinds.kdl
// Line 312-372: srcRules() parses window-rule blocks from window-rules.kdl
```

Changes needed:
1. Source paths: `dotfiles/niri/` → `dotfiles/hypr/`
2. KDL parser → Lua parser:
   - `srcSpawns`: parse `o.launch_on_start(...)` calls instead of `spawn-at-startup` lines
   - `srcBinds`: parse `o.bind(...)` calls instead of KDL binds blocks
   - `srcRules`: parse `o.window(...)` calls instead of KDL window-rule blocks
3. Staging dir: `build/niri-staging/` → `build/hypr-staging/`
4. File extensions: `.kdl` → `.lua`

The canonical encoding (Python-style repr for set comparison) stays the same — only the parsing logic changes.

## Input: niri-staging-validate → hypr-staging-validate (137 lines — key changes)

```go
// Line 99: staging = build/niri-staging → build/hypr-staging
// Line 113: exec.Command("niri", "validate", "-c", ...) → exec.Command("hyprland", "--validate", ...)
// Line 114: staging/config.kdl → staging/config.lua (or hyprland.lua)
// Line 128: "Apply to production only via: scripts/cue-validate.sh" → update to hypr-validate.sh
```

## Input: niri-backup → hypr-backup (289 lines — key changes)

```go
// Line 168: configDir = dotfiles/niri/.config/niri → dotfiles/hypr/.config/hypr
// Line 177: archive name: niri-config-* → hypr-config-*
// Line 221: restore path: ~/.config/ → ~/.config/ (same)
// Line 222: verify script name: backup-niri-config.sh → backup-hypr-config.sh
```

## Input: cmd/cue-validate/main.go (75 lines — full)

```go
// Line 64: "OK: CUE schemas validate (nightforge.niri)." → "(nightforge.hypr)."
```

## Launcher scripts to update (scripts/*.sh)

1. `scripts/cue-to-kdl.sh` → rename to `scripts/hypr-to-lua.sh`:
   - `BIN="$REPO_ROOT/build/bin/cue-to-kdl"` → `"$REPO_ROOT/build/bin/hypr-to-lua"`
   - `go build -o "$BIN" ./cmd/cue-to-kdl` → `./cmd/hypr-to-lua`

2. `scripts/cue-validate.sh` → rename to `scripts/hypr-valid.sh`:
   - Similar changes

3. `scripts/fidelity-check.sh` → rename to `scripts/hypr-fidelity-check.sh`:
   - Similar changes

4. `scripts/niri-staging-validate.sh` → rename to `scripts/hypr-staging-validate.sh`:
   - `BIN="$REPO_ROOT/build/bin/niri-staging-validate"` → `"$REPO_ROOT/build/bin/hypr-staging-validate"`
   - `go build -o "$BIN" ./cmd/niri-staging-validate` → `./cmd/hypr-staging-validate`

5. `scripts/backup-niri-config.sh` → rename to `scripts/backup-hypr-config.sh`:
   - `BIN="$REPO_ROOT/build/bin/niri-backup"` → `"$REPO_ROOT/build/bin/hypr-backup"`
   - `go build -o "$BIN" ./cmd/niri-backup` → `./cmd/hypr-backup`

6. Update `AGENTS.md` line 38: `./cmd/cue-validate/` → `./cmd/hypr-validate/`
7. Update `AGENTS.md` line 35: `./cmd/harnessd/` → keep (harnessd is unchanged)

## Expected Output

1. **New directory**: `cmd/hypr-to-lua/` — Go port of cue-to-kdl, generates Lua
2. **New directory**: `cmd/hypr-validate/` — Go port of cue-validate
3. **New directory**: `cmd/hypr-fidelity-check/` — Go port of fidelity-check with Lua parser
4. **New directory**: `cmd/hypr-staging-validate/` — Go port of niri-staging-validate
5. **New directory**: `cmd/hypr-backup/` — Go port of niri-backup
6. **Updated**: `internal/nfutil/nfutil.go` — Config struct field names updated for Hyprland
7. **New scripts**: `scripts/hypr-to-lua.sh`, `scripts/hypr-valid.sh`, `scripts/hypr-fidelity-check.sh`, `scripts/hypr-staging-validate.sh`, `scripts/backup-hypr-config.sh` (thin launchers)
8. **Updated**: `AGENTS.md` — update build commands
9. **Delete**: Old `cmd/niri-*` directories and `scripts/backup-niri-config.sh`, `scripts/cue-to-kdl.sh`, `scripts/cue-validate.sh`, `scripts/fidelity-check.sh`, `scripts/niri-staging-validate.sh`

## Acceptance Criteria

- All 5 new cmd/ directories created with working Go code
- `internal/nfutil/nfutil.go` updated with Hyprland field names
- All 5 new launcher scripts created (thin wrappers that build + exec)
- Old cmd/ directories deleted (niri-backup, niri-staging-validate, cue-to-kdl, cue-validate, fidelity-check)
- Old scripts deleted (backup-niri-config.sh, cue-to-kdl.sh, cue-validate.sh, fidelity-check.sh, niri-staging-validate.sh)
- `go build ./cmd/...` succeeds
- `go vet ./...` succeeds
- `AGENTS.md` updated with new build commands

## Rollback

```bash
git checkout -- cmd/ internal/ scripts/ AGENTS.md
```