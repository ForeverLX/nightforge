# GNHF MVP Harness Plan — libghostty Terminal with Agent-Mode Panes

**Date:** 2026-07-20 (S151)
**Status:** Research complete → Planning phase
**Blocking:** None — ready to implement

---

## Executive Summary

Build a **terminal emulator on libghostty** (not a separate CLI) where each pane/tab is a pre-configured agent mode (OMP, Hermes, Zero). herdr manages workspace layout. GNHF runs overnight autonomous builds. no-mistakes gates merges.

---

## Research Summary (Completed S150)

| Topic | File | Key Finding |
|-------|------|-------------|
| **libghostty API** | `ghostty-api-research.md` | C API + `apprt/embedded.zig` for programmatic embedding; Zig/Go/Rust bindings possible; not a widget toolkit |
| **CL4R1T4S prompts** | `cl4r1t4s-prompt-analysis.md` | 6 major agents analyzed (Claude Code, Cursor, Codex, Devin, Windsurf, Replit); 8 common patterns; none support multi-agent orchestration; designed 9-section template |
| **Existing tools gap** | `existing-tools-gap-audit.md` | Gateway: missing; Obs: partial (OTel SDK, no collector); Knowledge: covered (Hivemind); Eval: missing; Policy: missing |
| **GNHF** | `gnhf-repo-research.md` | npm package v0.1.41; TypeScript orchestrator; supports `acp:omp` agent; config at `~/.gnhf/config.yml` |
| **no-mistakes** | `no-mistakes-repo-research.md` | Go binary v1.37.0; local validation pipeline (intent→rebase→review→test→doc→lint→push+PR+CI); agent pinned to `acp:omp` |

---

## Architecture Decision

### Language: **Rust** (via `zig` bindings to libghostty)

**Rationale:**
- libghostty is written in Zig with C ABI
- Rust has mature `zig` crate for FFI, excellent terminal ecosystem (`ratatui`, `crossterm`, `alacritty` codebase)
- Single static binary, no runtime, matches Ghostty's performance profile
- Existing libghostty consumers (Ghostty itself) are Zig/C — Rust is the pragmatic choice for bindings

### Process Model

```
┌─────────────────────────────────────────────────────────────┐
│  harness (Rust) — libghostty embedded terminal             │
├─────────────────────────────────────────────────────────────┤
│  herdr IPC (Unix socket) — manages panes/tabs/workspaces   │
├─────────────────────────────────────────────────────────────┤
│  Pane 1: OMP agent    │  Pane 2: Hermes agent  │ Pane 3: Zero │
│  `omp --profile cr1ms0n`│  `hermes --profile cr1ms0n`│ `zero exec`  │
│  ACP server           │  ACP server            │ ACP server   │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Implementation |
|-----------|----------------|
| **Terminal core** | libghostty via `zig` crate → Rust `Terminal` struct |
| **Pane management** | herdr Unix socket API (existing `herdr pane` commands) |
| **Agent spawning** | Child process per pane: `omp acp`, `hermes acp`, `zero acp` |
| **ACP multiplexing** | Each pane runs ACP server on stdio; harness forwards JSON-RPC |
| **Config** | TOML at `~/.config/harness/config.toml` — pane layouts, agent profiles, keybindings |
| **GNHF integration** | `harness gnhf` command → spawns GNHF in background pane with `acp:omp` |

---

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

- [ ] **Rust project setup** — `cargo new harness`, add `zig` crate, `libghostty-sys` bindings
- [ ] **Minimal terminal** — embed libghostty, render single pane, handle input/output
- [ ] **herdr integration** — connect to herdr socket, list/create/destroy panes
- [ ] **Config system** — `config.toml` with pane layouts, agent commands, keybindings

### Phase 2: Agent Panes (Week 2-3)

- [ ] **ACP spawning** — per-pane child process with stdio pipes
- [ ] **Agent presets** — OMP (`omp --profile cr1ms0n acp`), Hermes (`hermes acp`), Zero (`zero acp`)
- [ ] **Pane lifecycle** — spawn on tab open, cleanup on close, persist session state
- [ ] **Keybindings** — `Ctrl+Shift+T` new tab, `Ctrl+Shift+W` close pane, `Ctrl+Tab` switch

### Phase 3: GNHF + no-mistakes Integration (Week 3-4)

- [ ] **GNHF command** — `harness gnhf "prompt"` spawns background GNHF with `acp:omp`
- [ ] **Background pane** — hidden pane runs GNHF, streams logs to visible log pane
- [ ] **no-mistakes gate** — `harness gate` runs `no-mistakes axi run` on current branch
- [ ] **Merge workflow** — GNHF commits → no-mistakes validates → auto-merge on pass

### Phase 4: Polish (Week 4-5)

- [ ] **Session persistence** — serialize pane layout + agent state on exit, restore on launch
- [ ] **Theming** — sync with Ghostty config (`~/.config/ghostty/config`)
- [ ] **Status line** — per-pane agent status (idle/busy/error), token usage, cost
- [ ] **Documentation** — man pages, `--help`, config reference

---

## Config Schema (TOML)

```toml
# ~/.config/harness/config.toml

[terminal]
font = "JetBrainsMono Nerd Font"
font_size = 13
theme = "dark"

[panes]
# Default layout on startup
default_layout = [
  { type = "horizontal", panes = ["omp", "hermes"] },
  { type = "vertical", panes = ["zero"] }
]

[agents.omp]
command = ["omp", "--profile", "cr1ms0n", "acp"]
env = { OMP_LOCAL_LLAMA_KEY = "" }
working_dir = "~"

[agents.hermes]
command = ["hermes", "acp", "--profile", "cr1ms0n"]
env = { BWS_ACCESS_TOKEN = "" }
working_dir = "~"

[agents.zero]
command = ["zero", "acp"]
working_dir = "~"

[keybindings]
new_tab = "Ctrl+Shift+T"
close_pane = "Ctrl+Shift+W"
next_pane = "Ctrl+Tab"
prev_pane = "Ctrl+Shift+Tab"
split_horizontal = "Ctrl+Shift+H"
split_vertical = "Ctrl+Shift+V"
gnhf_run = "Ctrl+G"
gate_run = "Ctrl+M"

[gnhf]
agent = "acp:omp"
max_iterations = 200
stop_condition = "10-layer architecture fully implemented and tested"
worktree_dir = "~/Documents/ai-lab-vault-gnhf-worktrees"

[no_mistakes]
repo_path = "~/Documents/ai-lab-vault"
gate_on_merge = true
```

---

## GNHF + no-mistakes Workflow

```bash
# 1. Start harness
harness

# 2. In any pane, run overnight build
harness gnhf "Implement L9 Optimization layer with eval-driven tuning"

# 3. GNHF runs in background pane (hidden), commits to worktree
#    Stream logs visible in dedicated log pane

# 4. Morning: review GNHF commits
harness gnhf status
harness gnhf logs

# 5. Run validation gate
harness gate --intent "L9 Optimization layer implementation"

# 6. If gate passes → auto-merge to main
#    If gate fails → review findings, fix, re-gate
```

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| libghostty API instability | Medium | High | Pin to specific Ghostty release; vendor `libghostty` source |
| ACP protocol changes | Low | Medium | Pin GNHF/OMP/Hermes/Zero versions; test matrix in CI |
| herdr API changes | Low | Medium | Use stable `herdr pane` CLI as fallback |
| GNHF overnight failures | Medium | Medium | Alert on failure (systemd notify + email); manual resume |
| no-mistakes false positives | Medium | Medium | Tune gate rules; `--skip` escape hatch |

---

## Next Steps

1. **Initialize Rust project** with `zig` crate and libghostty bindings
2. **Prototype single pane** with libghostty → verify input/output works
3. **Integrate herdr** for pane management
4. **Spawn first ACP agent** (OMP) in pane
5. **Iterate**

---

## References

- `40-Memory/Research/ghostty-api-research.md`
- `40-Memory/Research/cl4r1t4s-prompt-analysis.md`
- `40-Memory/Research/existing-tools-gap-audit.md`
- `40-Memory/Research/gnhf-repo-research.md`
- `40-Memory/Research/no-mistakes-repo-research.md`
- `10-Stack/gnhf-no-mistakes-pairing.md`
- `40-Memory/architecture/omp-observability-config.md`
- `40-Memory/architecture/hermes-observability-config.md`
- `10-Stack/10-layer-harness-build.md` (this doc updated with Memory Layer + Observability)