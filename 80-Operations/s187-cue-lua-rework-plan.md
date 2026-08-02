# S187 — NightForge CUE→Lua Rework Plan

**Status:** Planning document. Phase 1 (Go rewrite) is complete and
committed on `gnhf/continue-the-nightfo-0ada8e`; phases 2–5 are proposals.
Production config (`~/.config/niri`, `~/.config/quickshell`) is untouched.

**Owner:** pi (brain) + OMP (executor). **Constraint:** Rust/Go/C only for
new code. **Non-goal:** changing Niri or Quickshell behavior during
migration.

**Stack decision (2026-08-02, operator-validated):** custom **wgpu** shell
(§4.1), **Niri compositor blur** via `ext-background-effect` (§4.2),
**unix-socket event bus** (§4.3), separate Rust **wallpaper/video daemon**
(§4.4). Wayland + Niri stay. This is decided — Phase 4 executes it, it
does not re-evaluate it.

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
                    │  quickshell (reads QML) / wgpu shell       │
                    │  (unix-socket event bus, §4.3)             │
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
   is not available for Niri today, so KDL generation stays; the shell
   migrates to a custom wgpu renderer in Phase 4 (§4) — no framework
   markup format, Rust code renders directly from the CUE-derived JSON.

## 2. How This Changes the System

### 2.1 What replaces hand-edited KDL/QML

| Today | After |
|---|---|
| `dotfiles/niri/.config/niri/includes/keybinds.kdl` (hand-edited, 145 lines) | generated from `cue/nightforge.cue` by `cue-to-kdl` |
| `includes/window-rules.kdl` (hand-edited) | generated from CUE |
| `config.kdl` spawn-at-startup block | generated from CUE |
| `includes/{input,compositor,colors}.kdl` | **verbatim includes** (unchanged, copied byte-for-byte) — kept static because they are small, heavily commented, rarely edited |
| Quickshell QML (TopBar, popups) | unchanged in Phases 1–3; Phase 4 migrates to the custom wgpu shell (§4); Quickshell kept until coverage |

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

### 3.2 Quickshell replacement decision — **landed: custom wgpu shell**

Quickshell is an **active project** (2026) with layer-shell + IPC
integrations. NightForge depends on: TopBar, popups driven by
`/tmp/qs_widget_state`, lock screen, matugen theme sync, niri tweaks
scripts. Replacing it is a multi-week project, not a config swap.

**Decision (2026-08-02, operator-validated):** replace with a custom
wgpu shell (§4). The renderer, blur, event bus, and wallpaper daemon
decisions below are final — Phase 4 executes them, it does not
re-evaluate them. Quickshell stays installed until the wgpu shell
covers the surface; the `/tmp/qs_widget_state` router (keybinds +
`qs_manager.sh`) is the per-widget cutover point.

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

## 4. Shell Architecture — Final Stack (decided 2026-08-02)

Operator-validated Perplexity research. **Wayland stays** (no credible
alternative: X11 legacy, Mir niche, Arcan research); **Niri stays**
(compositor choice > protocol choice; Niri is Rust/Smithay-native).
The subsections below are the decided renderer/blur/bus/daemon stack.

### 4.1 Renderer: custom wgpu (primary); Slint demoted; hybrid optional

| Option | Paradigm | Verdict |
|---|---|---|
| **Custom wgpu shell** | Retained Rust renderer on `wgpu` (30.0.0), layer-shell surfaces via `smithay-client-toolkit`/sctk (0.21.1) | **Primary** — full shader/animations/surface control: text via glyph atlas (`cosmic-text` 0.19.0), rounded rects, gradients, image quads, canvas-style per-frame animation |
| **Slint** | Declarative `.slint` markup, Rust runtime | **Demoted** — acceptable only for *simple static panels* where declarative UI wins; weak for shaders, animations, surface control (original gap that motivated wgpu) |
| **Hybrid** | Slint panels + wgpu wallpaper/video | Viable option — more integration work (two render paths, two input models); not the default |
| Ratatui / iced / egui | TUI / Elm / immediate-mode | **Rejected** — evaluated in earlier drafts: Ratatui can't render a Wayland bar (needs a terminal); iced mainline is alpha-grade churn (COSMIC forks it for a reason); egui repaints per frame, weaker for polished multi-surface shells |

Slint's GPLv3/commercial licensing was the original friction; with Slint
demoted to optional simple panels, licensing is moot for the primary path.

**Spike gate (Phase 0, 1 day):** wgpu layer-shell proof on Niri — one
sctk layer-surface rendering text + rounded rect + gradient + one
animated quad; exclusive-zone/focus behavior verified. Proceed only if
the spike is green; otherwise fall back to the hybrid option (Slint
panels) while the wgpu path matures.

### 4.2 Blur: Niri compositor blur (ext-background-effect)

Niri v26.04 exposes compositor blur via the `ext-background-effect`
protocol. **xray blur (cheap) is the default for panels**; non-xray blur
when a surface needs it. No screenshot hacks, no client-side
pre-render pipeline as the primary path.

- Pre-render/ImageMagick blur (blurring an image asset, e.g. the album-
  art backdrop in the music popup) is **fallback only** — a blurred
  image quad is cheaper than a compositor blur over the whole surface
  for that one case.
- Perf mode (`performance-mode=low`) keeps disabling blur — the
  compositor effect is toggled off, not emulated.

### 4.3 Event bus: unix domain socket

Widget state propagates over a **unix domain socket** fan-out, NOT
`/tmp` files as the primary channel, NOT D-Bus as the central bus.

- One socket in `${XDG_RUNTIME_DIR}/nightforge/`; the shell and the
  daemons publish/subscribe JSON frames, one writer per topic
  (`theme`, `music`, `network`, `wallpaper`, `watcher`).
- `/tmp/qs_widget_state` **stays** as the keybind entry contract during
  migration (`echo music > /tmp/qs_widget_state` in
  `cue/nightforge.cue`) — a dispatcher bridges that file onto the
  socket; Phase 5 may point keybinds at the dispatcher binary directly
  and retire the file.
- `notify` (file watching) remains only for **file-backed inputs**: the
  matugen theme file (`/tmp/qs_colors.json`), config files, wallpaper
  dirs.
- The Go `qs-watcher` daemon's polled state (`/tmp/qs_watcher_state.json`)
  becomes one socket publisher instead of a polled file.

### 4.4 Wallpaper/video: separate Rust daemon

Wallpaper is its own daemon, not a shell widget:

- **Layer-shell surface per monitor**, per-output config (image, video,
  fit mode); hot-plug aware (react to output add/remove via
  `niri msg outputs` / wl-output events).
- **Decode:** `libmpv` (2.0.1) or `gstreamer` (0.25.3) for video,
  `image` crate (0.25.10) for stills.
- **Power-aware:** battery-aware framerate throttling (drop fps on
  battery), pause-when-occluded (no visible surface → stop decode).
- Replaces `awww` (image-only) as the long-term daemon; `awww` stays
  until the daemon covers stills + video.
- The wallpaper picker applies via this daemon (swww/swaybg as a
  stopgap) and triggers matugen after apply.

### 4.5 Widget backend decisions (short form)

| Widget | Backend |
|---|---|
| Music | `mpd_client` (1.4.1) push `idle` state; album art filesystem-first + `image` crate; art colors via `palette` (0.7.7) / `color_thief` (0.2.2); EQ over D-Bus via `zbus` (5.18.0) → EasyEffects |
| Network | NetworkManager D-Bus (`zbus`) for control flows (connect/disconnect/state/profiles); netlink for low-level status only |
| Wallpaper picker | `notify` dir watching; `image` crate thumbnails + disk cache; apply via wallpaper daemon; matugen trigger after apply |

Crate names verified on crates.io 2026-08-02. Full per-widget specs:
`80-Operations/s187-widget-extraction-specs.md`.

## 5. Phased Plan

| Phase | Scope | Status / Exit criteria |
|---|---|---|
| **1. Go rewrite** | Port all Python/bash migration tooling to Go (`cmd/*`, launchers in `scripts/`, shared `internal/nfutil`); update `docs/CUE-MIGRATION.md` | ✅ **DONE (S187)** — 6 commits; verified byte-identical outputs, 133/133 fidelity, `niri validate` green, backup interop |
| **2. CUE + Lua sandbox** | Spike sandbox host (mlua first — see §3.5); define pure JSON-transform contract; add `cmd/cue-transform`; extend schema for any imperative sections; keep pipeline deterministic | Lua step runs with zero side effects; fidelity-check still green; no production change |
| **3. KDL generation via Go** | Move static sections (input/compositor/colors) into CUE where they are stable, or keep verbatim includes; add coverage to fidelity-check; optional Go watcher for auto-regenerate (staging only) | Generated tree covers 100% of config.kdl; `niri validate` green; still no production writes |
| **4. wgpu shell build** | **Phase 0 spike: wgpu layer-shell proof (1 day, §4.1 gate)**; then shared plumbing (unix-socket bus, theme watcher, QsDirs); then music → wallpaper → network widgets on the wgpu renderer (§4.5, per-widget specs in `s187-widget-extraction-specs.md`); Quickshell kept until coverage; per-widget cutover via the `/tmp/qs_widget_state` router | Spike green; music widget live on the wgpu shell; daily driver unaffected; Quickshell still installed |
| **5. Full migration** | Flip production: generate `~/.config/niri/config.kdl` (+ shell config if replaced) from CUE; run watcher; `niri-backup` before first flip; rollback path documented in `docs/CUE-MIGRATION.md` | Production generated-config live; rollback drill performed; docs updated |

**Sequence rule:** phases 2–4 are independent of each other and safe to
run in parallel (no production writes); Phase 5 requires 2, 3, and 4
(the wgpu shell replaces Quickshell) to be complete.
