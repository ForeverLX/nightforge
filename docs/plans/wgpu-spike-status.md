# S187 — wgpu Spike Phase 0: Status

**Date:** 2026-08-03 (session S190)
**Owner:** OMP (executor) — plan: `80-Operations/s187-cue-lua-rework-plan.md` §4.1,
specs: `80-Operations/s187-widget-extraction-specs.md`
**Gate:** one sctk layer-surface on Niri rendering text + rounded rect +
gradient + one animated quad, with exclusive-zone and focus behavior
verified. **Result: GREEN — the custom wgpu shell path proceeds.**

## Deliverables

| Item | Where | Status |
|---|---|---|
| `nightforge-shell` crate (spike) | `shell/` | ✅ builds clean, `cargo test` 4/4 |
| Layer-shell + wgpu surface (sctk 0.21.1 + wgpu 30.0.0) | `shell/src/main.rs`, `render.rs` | ✅ live on Niri 26.04 |
| Text (cosmic-text 0.19 raster → texture) | `shell/src/text.rs` | ✅ renders |
| Rounded rect + gradient (SDF shader) | `shell/src/shape.wgsl` | ✅ renders |
| Animated quad (position + color pulse) | `shell/src/app.rs` | ✅ moves per frame |
| Exclusive zone / focus verification | — | ✅ verified (below) |
| Widget groundwork: `QsDirs` (§1.1) | `shell/src/dirs.rs` | ✅ tested |
| Widget groundwork: `Theme` 22-color (§1.3) | `shell/src/theme.rs` | ✅ tested, live theme loaded |
| Spike status + next steps | this doc | ✅ |

## Verification Evidence (live run, Niri 26.04, DP-1 1920×1080)

Ran `./target/debug/nightforge-shell` for ~2 min on the daily-driver session
(no config touched; surface removed on exit).

```
INFO app]   theme: base=0F0D12 (fallback=false)        ← live matugen palette, not Mocha fallback
INFO app]   dirs: cache=~/.cache/quickshell/shell run=/run/user/1002/quickshell/shell
INFO app]   configure: 1920x48
INFO render] surface configured: 1920x48 format=Bgra8UnormSrgb alpha=PreMultiplied present=Mailbox
INFO app]   keyboard focus entered/left layer surface  ← OnDemand focus behavior
INFO app]   pointer entered/left                       ← pointer events on the bar
```

- **Rendering (grim screenshots, ImageMagick pixel analysis):**
  - Bar occupies y 0–48 (avg `#1C191C`); window content below starts at
    y 48 (avg `#4F4B53`) → **exclusive zone 48 honored by Niri**.
  - Corner pixel (2,2) = desktop, not bar → **rounded corners**
    (SDF alpha edge works).
  - Mauve quad pixels found in bar (41 @ fuzz 12%); quad position
    between two screenshots 1 s apart: left/right split
    `23/18 → 106/48` → **quad animates** (position + color pulse).
- **Stability:** 0 errors/panics over the run; clean SIGTERM exit.
- **Tests:** `dirs.rs` (XDG/env-override contract) + `theme.rs` (hex
  parse, fallback, live JSON shape) — 4 passed.

## What Was Learned (API pins for the real shell)

- **wayland-client 0.31 default backend is pure-Rust** — it has NO
  `wl_display*` pointer, so wgpu's Vulkan WSI cannot use it. Must enable
  `wayland-client` feature **`system`** (libwayland) to get
  `conn.backend().display_ptr()`. Done in `shell/Cargo.toml`.
- **wgpu 30 API drift** (vs the sctk `wgpu.rs` example, which targets
  wgpu 0.19): `Instance::new(desc)` by value, `get_current_texture` →
  `CurrentSurfaceTexture` enum (Success/Suboptimal/Timeout/Occluded/
  Outdated/Lost), present is `queue.present(st)`, `RenderPass` ends on
  drop (no `.end()`), `RenderPassDescriptor.multiview_mask` +
  `RenderPassColorAttachment.depth_slice`, `PipelineLayoutDescriptor`
  takes `&[Option<&BindGroupLayout>]` + `immediate_size`,
  `RenderPipelineDescriptor.multiview_mask` (no `multiview`).
- **cosmic-text 0.19:** `Buffer::set_text(text, &attrs, shaping, align)`
  (no font_system arg), no `dimensions()` — compute extents from
  `layout_runs()`. `Buffer::draw` legacy renderer yields per-glyph-cell
  rects with coverage in alpha → premultiply on upload.
- **Spike render path:** no vertex buffer (expand unit quad from
  `@builtin(vertex_index)`), SDF rounded-rect in the fragment shader,
  premultiplied alpha everywhere (`CompositeAlphaMode::PreMultiplied`).

## Next Steps (Phase 0 plumbing, per widget spec §6)

1. **Shared plumbing (0.5–1 wk):** unix-socket event bus (§1.6) +
   dispatcher bridging `/tmp/qs_widget_state`; theme watcher on
   `/tmp/qs_colors.json` (notify crate, replace one-shot load); glyph
   atlas (persistent `cosmic-text` texture cache instead of per-string
   uploads); scene-graph scaling (`scale_factor`, §1.2).
2. **Phase 1 — Music core (1–2 wk):** `mpd_client` idle loop → publish
   `MusicState` on the bus; art cache + `palette` color extraction;
   cover/progress/controls scene.
3. **Phase 2 — Wallpaper local (2 wk):** grid + thumbs + apply + filters.
4. **Phase 3 — Network (2–3 wk):** tabs + list + connect flows.
5. Deferred: DDG search, EQ (zbus → EasyEffects), orbit visuals, video
   wallpapers (wallpaper/video daemon).

Cutover stays behind `/tmp/qs_widget_state`; Quickshell untouched.

## Open Questions (unchanged from spec §8)

- Niri blur: xray default for all panels or per-surface choice?
- `libmpv` vs `gstreamer` for the wallpaper/video daemon?
- EasyEffects in the NF audio stack (EQ phase)?
