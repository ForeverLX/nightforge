# NightForge CUE Migration

Migrate the Niri config authoring layer to **CUE** (cuelang.org) with schema
validation, while preserving all existing Niri and Quickshell behavior.

**Status: Phases 1–4 complete. Production config NOT changed.**

## Why CUE

Evaluated in S186: TOML lacks validation/schema, Lua is a security risk
(executable config). CUE provides typed schemas, constraint checking, and
deterministic data — it *generates* KDL for Niri (and later QML for
Quickshell) but does **not** replace the binaries. Niri compositor and
Quickshell stay; only the authoring layer changes.

## Scope Boundary

CUE covers the **structured, operator-edited sections**:

| Section | Source of truth |
|---------|-----------------|
| `spawn-at-startup` (8) | `cue/nightforge.cue` → generated |
| Keybinds (90) | `cue/nightforge.cue` → generated |
| Window rules (35) | `cue/nightforge.cue` → generated |
| `input.kdl`, `compositor.kdl`, `colors.kdl` | Static KDL includes, copied verbatim |

The static sections are small, rarely edited, and heavily commented; keeping
them as verbatim includes preserves behavior byte-for-byte.

## Layout

```
cue/
  cue.mod/module.cue   module nightforge.niri (language v0.17.1)
  schema.cue           #Config/#Spawn/#Bind/#WindowRule definitions
  nightforge.cue       the data (spawns, binds, window rules)
cmd/
  cue-to-kdl/          Phase 3: CUE data -> staging KDL tree (Go)
  fidelity-check/      Phase 3: generated vs source semantics diff (Go)
  cue-validate/        Phase 2: fmt + vet + export counts (Go)
  niri-backup/         Phase 1: sha256 checksummed backup + --verify (Go)
  niri-staging-validate/  Phase 4: full pipeline incl. `niri validate` (Go)
internal/nfutil/       shared repo-root + cue-export helpers
scripts/
  cue-validate.sh          thin launcher -> cmd/cue-validate
  backup-niri-config.sh    thin launcher -> cmd/niri-backup
  cue-to-kdl.sh            thin launcher -> cmd/cue-to-kdl
  fidelity-check.sh        thin launcher -> cmd/fidelity-check
  niri-staging-validate.sh thin launcher -> cmd/niri-staging-validate
docs/CUE-MIGRATION.md      this file
```

## Toolchain

All migration tools are Go (repo convention: Rust/Go/C only; the original
Python scripts from the gnhf overnight run were rewritten in S187). The
`.sh` files in `scripts/` are thin launchers that build the Go binary on
demand into `build/bin/` (gitignored) and exec it — no Python, no jq.
Build everything at once with `go build ./cmd/...`.

```bash
# optional: prebuild all tools
mkdir -p build/bin && go build -o build/bin/cue-to-kdl ./cmd/cue-to-kdl && \
  go build -o build/bin/fidelity-check ./cmd/fidelity-check && \
  go build -o build/bin/cue-validate ./cmd/cue-validate && \
  go build -o build/bin/niri-backup ./cmd/niri-backup && \
  go build -o build/bin/niri-staging-validate ./cmd/niri-staging-validate
```

Generated KDL comments name the tool as `cue-to-kdl` (the Go binary); the
original `cue-to-kdl.py` string was dropped — that is the only byte-level
difference from the Python generator output. Semantics are unchanged and
verified by fidelity-check.

## Verification Evidence (reproduce)

```bash
# Phase 1 — checksummed backup (default ~/Backups/nightforge/pre-cue-migration/)
scripts/backup-niri-config.sh --target build/backup-test
scripts/backup-niri-config.sh --verify build/backup-test   # tampering => exit 1

# Phase 2 — schema validation
scripts/cue-validate.sh    # cue fmt --check + cue vet + export counts

# Phases 3–4 — dry-run generation, fidelity, staging validation
scripts/niri-staging-validate.sh
#   1. cue-to-kdl generates build/niri-staging/
#   2. fidelity-check: 133 canonical entries (8 spawns + 90 binds + 35
#      rules) match the source KDL semantics exactly
#   3. niri validate -c build/niri-staging/config.kdl  -> "config is valid"
```

Last verified run (all green):

```
== spawn-at-startup: source=8 generated=8
== keybinds: source=90 generated=90
== window-rules: source=35 generated=35
OK: 133 canonical entries match source semantics exactly.
INFO niri: config is valid
```

## Fidelity Methodology

Both the source KDL and the generated KDL are parsed into the same canonical
structures and diffed as sets (order-independent). The canonical forms use
Python-style repr encodings (`('spawn', ('ghostty',))`), so the Go
fidelity-check output is byte-identical to the original Python script.

- **spawn-at-startup**: argv token tuples
- **keybinds**: `(combo, flags, action)` with flags normalized to
  `(key, value)` pairs and actions as `("spawn", argv)` or
  `("builtin", name, arg)`
- **window-rules**: `(match clauses, sorted properties)` with numeric
  normalization (`0.90` == `0.9`)

Parser notes: `//` comments are stripped only outside quoted strings (so
`obsidian://daily` survives); quoted flag values containing spaces are kept
intact; multiple match clauses on one line are supported.

## Rollback Procedure

The migration is **additive** — production `~/.config/niri` is never touched
by any script in this repo (all operate on `dotfiles/` or `build/`).

If a future deploy of the generated config is bad:

1. **Restore the pre-migration backup**:
   ```bash
   # find the archive
   ls -la ~/Backups/nightforge/pre-cue-migration/
   # verify checksums before restoring (must print all OK)
   scripts/backup-niri-config.sh --verify ~/Backups/nightforge/pre-cue-migration
   # restore into place (only if you actually applied the migration)
   tar -xzf ~/Backups/nightforge/pre-cue-migration/niri-config-<stamp>.tar.gz -C ~/.config/
   ```

2. **Fall back to git**: the tracked config under `dotfiles/niri/.config/niri/`
   is unchanged by the migration — `git checkout -- dotfiles/niri/` restores
   the exact pre-migration tree at any time.

3. **Validate before/after any apply**: `niri validate -c <config>` accepts
   the config, or fails loudly before the compositor starts.

4. **Quickshell is unaffected**: the migration covers Niri config only;
   Quickshell QML files are not modified.

## Constraints Honored

- No production config changed (`~/.config/niri`, `~/.config/quickshell`
  untouched)
- No pushes, no deploys — staging validation is the gating step
- Generated artifacts are reproducible: `build/niri-staging/` is rebuilt
  deterministically from `cue/` (and is gitignored)
