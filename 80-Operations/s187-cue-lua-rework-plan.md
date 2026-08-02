# S187 — NightForge CUE→Lua Rework Plan

**Status:** Planning document. Phase 1 (Go rewrite) is complete and
committed on `gnhf/continue-the-nightfo-0ada8e`; phases 2–5 are proposals.
Production config (`~/.config/niri`, `~/.config/quickshell`) is untouched.

**Owner:** pi (brain) + OMP (executor). **Constraint:** Rust/Go/C only for
new code. **Non-goal:** changing Niri or Quickshell behavior during
migration.

---

## 1. Target Architecture

```
                    ┌────────────────────────────────────────────┐
                    │  cue/nightforge.cue  ── SOURCE OF TRUTH    │
                    │  cue/schema.cue      (typed, validated)    │
                    └───────────────┬────────────────────────────┘
                                    │ cue eval / export (JSON)
                                    ▼
                    ┌────────────────────────────────────────────┐
                    │  Lua sandbox (escape hatch)                │
                    │  pure transform: JSON in → JSON out        │
                    │  (decision point: mlua vs WASM-hosted Lua) │
                    └───────────────┬────────────────────────────┘
                                    │ JSON
                                    ▼
                    ┌────────────────────────────────────────────┐
                    │  Go toolchain (cmd/*)                      │
                    │  cue-validate → cue-to-kdl → fidelity-check│
                    │  niri-staging-validate → niri-backup       │
                    └───────────────┬────────────────────────────┘
                                    │ KDL  (Niri)   /  QML  (Quickshell)
                                    ▼
                    ┌────────────────────────────────────────────┐
                    │  niri (reads KDL, live-reloads)            │
                    │  quickshell (reads QML, live-reloads)      │
                    └────────────────────────────────────────────┘
```

Layers:

1. **CUE = source of truth.** Schemas (`cue/schema.cue`) + data
   (`cue/nightforge.cue`). Everything operator-edited lives here;
   `cue vet` gates structure, `cue fmt --check` gates style.
2. **Lua sandbox = escape hatch for logic CUE cannot express.** CUE is
   data + constraints, not imperative code. The sandbox is a *pure
   transform step*: receives the exported JSON, returns modified JSON,
   with no filesystem/network/side-effect access. It earns its place only
   for genuinely imperative needs (e.g. generating binds from a monitor
   list, computing values from runtime inputs like the current wallpaper).
   Most repetition CUE already handles with comprehensions
   (`[for i in list ...]`) — the Lua step is for what CUE cannot.
3. **Go/Rust toolchain = converters, validation, staging** (Phase 1 done):
   `cue-validate`, `cue-to-kdl`, `fidelity-check`, `niri-backup`,
   `niri-staging-validate`. Deterministic, stdlib-only, no network deps.
4. **Output = native formats.** Niri consumes KDL (see Risks §3.1 — there
   is no native CUE support), Quickshell consumes QML. "Better than KDL"
   is not available for Niri today, so KDL generation stays; for the shell
   the Phase 4 decision may move to a framework's native format.

## 2. How This Changes the System

### 2.1 What replaces hand-edited KDL/QML

| Today | After |
|---|---|
| `dotfiles/niri/.config/niri/includes/keybinds.kdl` (hand-edited, 145 lines) | generated from `cue/nightforge.cue` by `cue-to-kdl` |
| `includes/window-rules.kdl` (hand-edited) | generated from CUE |
| `config.kdl` spawn-at-startup block | generated from CUE |
| `includes/{input,compositor,colors}.kdl` | **verbatim includes** (unchanged, copied byte-for-byte) — kept static because they are small, heavily commented, rarely edited |
| Quickshell QML (TopBar, popups) | unchanged in Phases 1–3; Phase 4 decides (keep / swap framework) |

Operator workflow becomes: **edit CUE → run `scripts/cue-validate.sh` →
`scripts/niri-staging-validate.sh` → review → deploy**. Hand-editing KDL
generated sections is discouraged; fidelity-check catches any drift.

### 2.2 Build pipeline

```
cue fmt --check  →  cue vet  →  cue export  →  [lua transform]  →
cue-to-kdl (render KDL tree)  →  fidelity-check (vs source semantics)  →
niri validate -c staging/config.kdl  →  niri-backup (pre-deploy)  →  deploy
```

Every stage is a separate Go binary with a deterministic contract; the
staging tree in `build/niri-staging/` is the single handoff artifact.
`build/` is gitignored.

### 2.3 Hot-reload implications

- **Niri:** watches `config.kdl` and live-applies changes on save
  (verified on niri 26.04); invalid configs keep the last good state and
  log an error. So deployment = writing the generated file; reload is
  automatic. The gating step (`niri validate`) happens *before* the file
  reaches `~/.config/niri`.
- **Quickshell:** has its own live-reload for QML. Same pattern: generate
  into staging, validate, then write.
- **Optional Phase 5 addition:** a small Go watcher on `cue/` that
  regenerates → validates → writes to production with automatic rollback
  on `niri validate` failure. This makes CUE edits hot. It must NOT run
  during phases 1–4 (daily-driver safety).

### 2.4 Where the Lua sandbox plugs in

Between `cue export` and the renderers (see diagram). Contract: stdin =
exported config JSON, stdout = transformed JSON, exit 0. This keeps the
pipeline deterministic (same input → same output), testable, and lets
`fidelity-check` keep working unchanged (it validates the *rendered*
artifact against source semantics).

## 3. Risks

### 3.1 Niri compatibility — **KDL stays required**

Verified 2026-08: niri (installed 26.04) reads **KDL only**; no native
CUE support exists. `niri validate -c` is the acceptance gate. Risk of
niri changing config format: low (KDL is its documented, stable format),
but a future niri could break a generated keyword — mitigated by staging
validation before any deploy.

### 3.2 Quickshell replacement decision

Quickshell is an **active project** (2026) with layer-shell + IPC
integrations. NightForge depends on: TopBar, popups driven by
`/tmp/qs_widget_state`, lock screen, matugen theme sync, niri tweaks
scripts. Replacing it is a multi-week project, not a config swap.
Decision deferred to Phase 4 with evaluation inputs below.

### 3.3 Migration breakage on the daily driver

Mitigations already in place: production never touched by any tool (all
operate on `dotfiles/` or `build/`); checksummed backup +
`--verify` (`niri-backup`); `niri validate` before apply; git rollback
(`dotfiles/niri/` stays tracked); fidelity-check guarantees generated KDL
matches source semantics. The remaining risk is *semantic* drift in
sections not covered by fidelity (static includes are copied verbatim, so
risk ≈ 0).

### 3.4 Toolchain complexity

CUE + Go + (Lua) + renderers = more moving parts than one KDL file.
Mitigations: stdlib-only Go (zero module deps), pinned CUE language
version (`v0.17.1` in `cue.mod`), one documented pipeline, and *no* new
language in the pipeline unless the sandbox decision lands. Each tool is
a thin single-purpose binary.

### 3.5 wasmtime-lua does not exist as a maintained crate

Research (2026-08): there is **no maintained `wasmtime-lua` crate** —
wasmtime itself is actively maintained (v47.0.0, 2026-07; LTS program),
but "Lua in WASM" projects are PoC-level (Wasmoon targets JS runtimes;
Rust `WebAssembly-Lua`/`Wasm_Lua` unmaintained). Decision point for
Phase 2:

- **(a) mlua** (pure-Rust Lua, optional vendored interpreter, no C
  toolchain) with a strict sandbox (no `io`/`os`/`package` libs,
  byte budget, pure-function contract). Pragmatic, maintained.
- **(b) WASM-hosted Lua** via wasmtime: strongest isolation, but the Lua
  side is a build step (compile Lua to WASM) with unmaintained tooling.
- Recommendation: **(a) mlua first**, revisit (b) if untrusted
  third-party scripts become a requirement. The transform contract (JSON
  in/out) makes swapping hosts trivial.

## 4. Quickshell Replacement Evaluation (inputs for Phase 4)

Frameworks under consideration, with 2026 state:

| Option | Paradigm | Fit for NightForge shell | Verdict |
|---|---|---|---|
| **Slint** | Declarative `.slint` markup, Rust runtime | Polished UI, good docs, renderer abstraction; needs layer-shell integration via smithay-client-toolkit; **license** is GPLv3/commercial (royalty-free tier exists for small orgs) | Strong candidate for a *custom* bar/widget shell; licensing must be accepted |
| **Ratatui** | TUI (terminal) | Cannot render a Wayland bar (needs a terminal); useful only as a fallback operator dashboard in a terminal | **Rejected** for shell duty |
| **iced** | Elm-style declarative, pure Rust | Most complete pure-Rust GUI; COSMIC (System76) uses a fork for a full desktop — proof it can carry a shell; wgpu backend + layer-shell integration is custom work | Strong candidate; expect alpha-grade API churn on mainline (COSMIC is a fork for a reason) |
| **egui** | Immediate mode, pure Rust | Trivial to build dashboards/panels; repaints per frame (fine for a bar); layer-shell via egui-winit is DIY; less suited to polished multi-surface shells | Best for *operator widgets/tools*, weaker as a shell base |

Prebuilt Rust bars (Eww, ironbar, Riftbar, wayle) cover the "bar only"
use case with JSON/YAML config — no QML, no custom GUI code. They do not
cover NightForge's popup/lock/OSD widgets.

**Phase 4 recommendation path:** (1) define the required surface (top
bar, popups, lock, OSD, matugen theme, `/tmp/qs_widget_state` IPC);
(2) spike **ironbar/wayle** for bar-only coverage; (3) if widgets stay,
spike **Slint** vs **iced** for the custom shell; (4) keep Quickshell
until a spike covers 100% of the surface. Replacing Quickshell is
optional — "keep" is a valid outcome.

## 5. Phased Plan

| Phase | Scope | Status / Exit criteria |
|---|---|---|
| **1. Go rewrite** | Port all Python/bash migration tooling to Go (`cmd/*`, launchers in `scripts/`, shared `internal/nfutil`); update `docs/CUE-MIGRATION.md` | ✅ **DONE (S187)** — 6 commits; verified byte-identical outputs, 133/133 fidelity, `niri validate` green, backup interop |
| **2. CUE + Lua sandbox** | Spike sandbox host (mlua first — see §3.5); define pure JSON-transform contract; add `cmd/cue-transform`; extend schema for any imperative sections; keep pipeline deterministic | Lua step runs with zero side effects; fidelity-check still green; no production change |
| **3. KDL generation via Go** | Move static sections (input/compositor/colors) into CUE where they are stable, or keep verbatim includes; add coverage to fidelity-check; optional Go watcher for auto-regenerate (staging only) | Generated tree covers 100% of config.kdl; `niri validate` green; still no production writes |
| **4. Quickshell replacement evaluation** | Use §4 matrix; spike bar candidates + custom shell frameworks; decide keep/replace; if replace: plan QML→framework migration (or CUE→native format) | Documented decision with spike evidence; daily driver unaffected |
| **5. Full migration** | Flip production: generate `~/.config/niri/config.kdl` (+ shell config if replaced) from CUE; run watcher; `niri-backup` before first flip; rollback path documented in `docs/CUE-MIGRATION.md` | Production generated-config live; rollback drill performed; docs updated |

**Sequence rule:** phases 2–4 are independent of each other and safe to
run in parallel (no production writes); Phase 5 requires 2 and 3 (and 4
if replacing the shell) to be complete.
