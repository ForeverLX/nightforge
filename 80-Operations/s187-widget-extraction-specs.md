# S187 — Widget Extraction Specs: Wallpaper / Music / Network → Rust (wgpu)

**Status:** Analysis + extraction spec. Read-only pass over
`~/Github/nixos-configuration` (reference, ilyamiro Hyprland dotfiles) and
`~/Github/imperative-dots`. No production writes, no push, Quickshell
fallback intact.

**Owner:** pi (brain) + OMP (executor). **Constraint:** Rust/Go/C only for
new code (S187). Custom wgpu renderer is the target (decided 2026-08-02,
see `80-Operations/s187-cue-lua-rework-plan.md` §4); Slint is acceptable
only for simple static panels; hybrid (Slint panels + wgpu wallpaper/video)
is the documented fallback.

**NightForge target stack (already live):** Niri + `awww` wallpaper
daemon (not swww/mpvpaper), MPD (not playerctl), Matugen pipeline writing
`/tmp/qs_colors.json`, Go `qs-watcher` daemon
(`scripts/qs-watcher/main.go`, 978 ln, writes `/tmp/qs_watcher_state.json`),
widget IPC via `/tmp/qs_widget_state` + `qs_manager.sh` flock router.

**Target stack (decided 2026-08-02, replaces the above incrementally):**
custom **wgpu** shell on layer-shell surfaces (`smithay-client-toolkit`),
**unix-socket event bus** fans widget state out (see §1.6), **Niri
compositor blur** (`ext-background-effect`, xray default — no screenshot
hacks), separate Rust **wallpaper/video daemon** (`libmpv`/`gstreamer`
decode), NetworkManager D-Bus (`zbus`) for network control, `zbus` →
EasyEffects for EQ.

Crate names verified on crates.io 2026-08-02: `wgpu` 30.0.0,
`smithay-client-toolkit` 0.21.1, `zbus` 5.18.0, `notify` 9.0.0-rc.4,
`mpd_client` 1.4.1, `libmpv` 2.0.1, `image` 0.25.10, `palette` 0.7.7,
`color_thief` 0.2.2, `cosmic-text` 0.19.0, `gstreamer` 0.25.3.

---

## 0. Executive Summary

| Widget | Reference LOC | NF QML today | Port value | Complexity | Verdict |
|---|---|---|---|---|---|
| WallpaperPicker | 1,826 (QML) + 3 scripts | 217 (simplified) | **High** — daily driver feature | **High** | Port in 3 phases; skip online search v1, keep local grid+apply |
| MusicPopup | 1,473 (QML) + 3 scripts | 118 (MPD, bare) | **High** — most polished surface | **Medium** | Port core + art-derived colors; skip EQ/lightning v1 |
| NetworkPopup | 2,367 (QML) + 3 scripts | 390 (list-based) | **Medium** — connect flow is the value | **High** | Port list+tabs+connect; skip orbit/radar/lightning visuals |

**Port priority:** Phase 0 spike = **wgpu layer-shell proof (1 day)**, then
shared plumbing (theme watcher, dir cache, unix-socket event bus), then
1. Music core → 2. Wallpaper local grid → 3. Network list+connect.

**Key port decisions (rationale in §7):**
- **Keep shell backends** (`*_panel_logic.sh`, `music_info.sh`) as
  subprocess contracts in v1 — they are battle-tested, fast (sysfs
  presence checks avoid D-Bus hangs), and already emit clean JSON. Port
  to Rust only where a crate gives a strict win (MPD client).
- **MatugenColors** → Rust watcher on `/tmp/qs_colors.json` (notify or
  1 s poll), keep same 22-color contract; honor NightForge performance
  mode (low = no blur/animations) — already exists in NF service.
- **Qt-only rendering is replaced by wgpu primitives** (MultiEffect
  blur/shadow, Matrix4x4 skew, Canvas 2D lightning, QtMultimedia video
  preview). wgpu gives: text (glyph atlas via `cosmic-text`), rounded
  rects, gradients, image quads, canvas-style per-frame animation. Blur
  comes from the **Niri compositor** (`ext-background-effect`, xray
  default) instead of client-side effects. NightForge
  `performance-mode=low` keeps disabling blur/animations.
- **Video wallpapers**: handled by the new wallpaper/video daemon
  (rework plan §4.4) — layer-shell surface per monitor, `libmpv`/
  `gstreamer` decode, per-output config, hot-plug aware, battery-aware
  framerate throttling, pause-when-occluded. `awww` (image-only) stays
  until the daemon covers stills + video; until then `000_*.mp4` tiles
  show "video (daemon pending)" rather than pretending parity.

---

## 1. Shared Patterns (port once, reuse everywhere)

### 1.1 Caching / dirs — `Caching.qml` + `caching.sh`

**Reference contract** (`Caching.qml`, `scripts/caching.sh`):

| Dir | Path | Env override |
|---|---|---|
| cache | `~/.cache/quickshell/<widget>` | `QS_CACHE_<WIDGET>` |
| state | `~/.local/state/quickshell/<widget>` | `QS_STATE_<WIDGET>` |
| run (tmpfs) | `${XDG_RUNTIME_DIR:-/tmp}/quickshell/<widget>` | `QS_RUN_<WIDGET>` |
| log | `$RUN/logs` | — |

`caching.sh` pre-initializes every `quickshell/*/` widget dir on source.
Widgets call `qs_ensure_cache "name"` then read `$QS_RUN_<NAME>` etc.

**NightForge already mirrors this** (`dotfiles/.../scripts/` ships the
watchers + `qs_manager.sh`; Go daemon writes `/tmp/qs_watcher_state.json`).
Keep the contract identical in Rust:

```
// wgpu shell side: PathBuf resolvers only (no mkdir per call)
struct QsDirs { cache: PathBuf, state: PathBuf, run: PathBuf, log: PathBuf }
impl QsDirs { fn for_widget(name) -> Self { /* XDG env override, else defaults */ } }
```

Decide once: NightForge IPC already uses `/tmp/qs_*` directly
(`/tmp/qs_widget_state`, `/tmp/qs_watcher_state.json`). During migration
the wgpu shell keeps `/tmp/qs_widget_state` as the keybind entry contract
(drop-in for keybinds) and a dispatcher bridges it onto the unix-socket
event bus (§1.6); state fans out over the socket, not by polling files.

### 1.2 Scaler — `Scaler.qml` + `WindowRegistry.js`

Reference math (`WindowRegistry.js:getScale`):
```
r = min(mw/1920, mh/1080)
scale = r <= 1.0 ? max(0.35, r^0.85) : r^0.5
scale *= uiScale   // from ~/.config/hypr/settings.json
s(val) = round(val * scale)
```
`Scaler.qml` reads `settings.json` once + inotifywatches it
(`inotifywait -qq -e modify,close_write`) for live uiScale changes.

**Port:** one `scale_factor()` fn in Rust; watch
`~/.config/nightforge/*` settings (or keep Quickshell settings.json
format for drop-in compat). The wgpu shell multiplies every layout
length by `scale` at the scene-graph root — same math, no framework
scaling layer to fight. **Verify:** computed sizes match the reference
pow-curve — minor visual delta acceptable.

### 1.3 Theme — `MatugenColors.qml`

- Polls `/tmp/qs_colors.json` every 1 s (`cat` + JSON parse), 22 named
  colors, Catppuccin-Mocha fallbacks.
- Written by `matugen-sync.sh` (jq transform of matugen `colors.json`).
- NightForge version adds `performanceMode` (low/high → blurEnabled/
  animationEnabled) polling `~/.config/nightforge/performance-mode`.

**Port:** `theme.rs` — watch `/tmp/qs_colors.json` (notify crate, or 1
s timer mirroring QML), parse into `Theme { base, mantle, crust, text, ... }`,
push into the renderer's shared palette; the scene graph re-reads colors
each frame (theme change → next frame repaints, no binding layer).
Keep perf-mode: gate blur/animations on `theme.animation_enabled` in
the frame loop.

### 1.4 Watcher pattern — `watchers/*_{fetch,wait}.sh`

Two-part pattern used for audio/battery/bt/kb/network:

- **`*_fetch.sh`**: stateless read → JSON (or pipe) on stdout. Fast,
  sysfs-first, LC_ALL=C, hard timeouts on D-Bus tools
  (`timeout 1.5 playerctl`, `timeout 0.5 wpctl`, `timeout 1 bluetoothctl`).
- **`*_wait.sh`**: **blocking event gate** — mkfifo + `trap 'rm fifo;
  kill $MONITOR_PID' EXIT`, spawn a monitor (`pactl subscribe`,
  `udevadm monitor --subsystem-match=power_supply` w/ `timeout 10`
  failsafe, `dbus-monitor` bluez filters, `nmcli monitor`, `socat`
  Hyprland socket2 for `activelayout>>`, `inotifywait` on settings
  files), grep -m1 for the event, exit → QML re-fetches.

The pattern exists **because** `pactl subscribe` / `bluetoothctl` /
`nmcli monitor` are not reliable as long-lived streams (hang, D-Bus
exhaustion); the wait script bounds each subscription and cleans up.

**NightForge already ported this to Go** — `scripts/qs-watcher/main.go`
has `fetch <type>`, `watch <type>`, and a `daemon` that loops all
fetches every 3 s writing `/tmp/qs_watcher_state.json`. Watchers match
reference semantics exactly (pactl subscribe regex, udevadm, nmcli
monitor, dbus bluez, socat hypr).

**Port decision:** extend the Go daemon (add `music`, `wallpaper`
slots) rather than reimplement in Rust; the daemon becomes a
**publisher on the unix-socket event bus** (§1.6) instead of the sole
writer of a polled file. Widget state fans out over the socket; `notify`
is reserved for file-backed inputs (`/tmp/qs_colors.json`, config,
wallpaper dirs). This is the single biggest architectural win of the
port: **unix-socket event bus instead of subprocess-per-widget or file
polling.**

```
bash fetch (v1, keep)  ─┐
Go qs-watcher daemon    ─┼─>  unix socket (${XDG_RUNTIME_DIR}/nightforge/)  ──>  wgpu shell
nmcli/bluetoothctl (ops)─┘        (JSON frames per topic)                  (parse JSON → scene)
                                      ▲
keybind: echo music > /tmp/qs_widget_state ─ dispatcher bridges file → socket
```

### 1.5 Widget IPC — `/tmp/qs_widget_state` (migration entry point)

Niri keybinds write `echo music|network|wallpaper > /tmp/qs_widget_state`;
`qs_manager.sh` routes with flock; shell.qml watches with inotifywait +
clears file. **The wgpu shell keeps this file contract during migration**
— keybinds stay unchanged. A dispatcher bridges the file event onto the
unix-socket bus (§1.6); Phase 5 may point keybinds at the dispatcher
binary directly (`nightforge-widgets music`) and retire the file.

---

### 1.6 Event bus — unix domain socket (decided)

Widget/daemon state propagates over a **unix domain socket** fan-out in
`${XDG_RUNTIME_DIR}/nightforge/` — NOT `/tmp` files as the primary
channel, NOT D-Bus as the central bus.

- JSON frames, one writer per topic (`theme`, `music`, `network`,
  `wallpaper`, `watcher`); the shell and daemons subscribe per topic.
- Sources: Go `qs-watcher` daemon publishes polled state; `mpd_client`
  `idle` loop publishes music changes; `zbus` listeners (NetworkManager,
  EasyEffects) publish network/EQ state; the dispatcher bridges
  `/tmp/qs_widget_state` keybind writes onto the socket (§1.5).
- `notify` stays for **file-backed inputs only**: `/tmp/qs_colors.json`
  (matugen theme), config files, wallpaper/thumbnail dirs.
- One code path in the shell: socket reader → typed state → scene
  update. No per-widget process babysitting, no poll timers.

## 2. Wallpaper Picker — `wallpaper/WallpaperPicker.qml` (1,826 ln)

### 2.1 Feature inventory

| # | Feature | Details | Port worth |
|---|---|---|---|
| W1 | Full-screen horizontal cover-flow grid | `ListView` horizontal, center-enlarged item (1.5×), Matrix4x4 skew, z-layering, fade-out non-matching, wheel-scroll accumulator + threshold + 150 ms throttle, StrictlyEnforceRange | **High** (define experience) |
| W2 | Keyboard navigation | Left/Right step, Return=apply, Escape=exit search, Tab/Backtab cycle filter, focus snap w/ `positionViewAtIndex(Center)` | **High** (trivial in wgpu — index state) |
| W3 | Color filters | All/Video/Red/Orange/Yellow/Green/Blue/Purple/Pink/Monochrome; HSV bucketing of per-image hex (`getHexBucket`); `colors_markers/<name>_HEX_<hex>` marker files; filter chips bar w/ animated selection | **High** |
| W4 | Search filter (local name) | TextInput → filter mode "Search", query persisted in QSettings | Medium |
| W5 | **Online search (DDG)** | `ddg_search.sh` pipeline: python `get_ddg_links.py` (VQD token, 5 pages) → pipe thumb|full URLs → curl thumbnails w/ HEAD pre-flight, mime check, webp→magick convert, incremental arrival via FolderListModel; pause/stop control file; search_map.txt; apply→download full res | **Low for v1** (scraper fragility, IP surface) |
| W6 | Thumbnail cache | `~/.cache/quickshell/wallpaper_picker/thumbs`; magick resize x420 q70; video thumbs same dir w/ `000_` prefix | **High** |
| W7 | Dominant-color extraction | magick histogram → `colors.csv` → marker files; `triggerColorExtraction` on startup; cacheVersion invalidation | **High** (powers W3) |
| W8 | Apply wallpaper | swww img / mpvpaper (reference, Hyprland) → **awww img (NF)**; random transition; monitor-target selection (hyprctl monitors -j, multi-monitor apply); logs `swww_debug.log`; `current_wallpaper.png` copy | **High** (awww swap) |
| W9 | Matugen reload on apply | `matugen image <thumb>` + `matugen_reload.sh` (kitty/cava/swaync/GTK reload) → NF: `matugen-sync.sh` | **High** |
| W10 | Video preview | QtMultimedia MediaPlayer inline preview on focus (muted, loop) | **Skip** (no Qt; awww can't set video) |
| W11 | Status chrome | notification drawer (spinner + status text), monitor selector drawer, pause/play search btn | Medium |
| W12 | State restore | QSettings: query/searched/lastName; focus restore to last wallpaper | Medium |

### 2.2 QML architecture

- Root `Item` (window-sized). Children: `ListView view` (delegate = skew
  card + video preview), `filterBarBackground` (chips + notif drawer +
  monitor drawer + search box), overlay controls.
- **Models:** `srcModel` (wallpaper dir), `localFolderModel` (thumbs),
  `searchFolderModel` (search_thumbs) — all `FolderListModel`; proxy
  `ListModel`s `localProxyModel`/`searchProxyModel` synced incrementally
  (`_localSyncedCount`), `markerModel` (color markers), `monitorModel`.
- **Key properties:** `currentFilter`, `searchQuery`, `colorMap`,
  `cacheVersion`, `isApplying`, `isDownloadingWallpaper`,
  `isSearchPaused`, `hasSearched`, `visibleItemCount`, `isReady`,
  `isScrollingBlocked`, `lastSearchName`.
- **Key signals/functions:** `applyWallpaper(file,isVideo)` (bash script
  assembly w/ escaping), `triggerOnlineSearch()`, `tryFocus()`,
  `syncLocalModel()`/`syncSearchModel()` (incremental append),
  `processMarkers()`, `triggerColorExtraction()`, `stepToNextValidIndex()`,
  `cycleFilter()`, `applyFilters(forceSnap)`.
- `Settings { category: "QS_WallpaperPicker" }` persists search state.
- `Process` + `StdioCollector` for monitor sync; `execDetached` for all
  side effects.

### 2.3 Data flow

```
[wallpaper dir] ──FolderListModel──> srcModel ─┐
[thumbs cache]  ──FolderListModel──> localFolderModel ─sync─> localProxyModel ─> ListView
[search_thumbs] ──FolderListModel──> searchFolderModel ─sync─> searchProxyModel ─┘
[markers dir]   ──FolderListModel──> markerModel ─processMarkers─> colorMap + cacheVersion
[ddg pipeline]  ──writes files──> search_thumbs (incremental, event-driven)
apply ──execDetached bash──> swww/mpvpaper + matugen + reload   (NF: awww + matugen-sync.sh)
```

All file-system driven for inputs — **no D-Bus for discovery**; apply
and status ride the event bus (§1.6). This maps perfectly to Rust
`notify` + a scene model.

### 2.4 Theme integration

- `MatugenColors { id: _theme }` everywhere; filter chips use literal
  color hexes for buckets (Red #FF4500 … Monochrome #A9A9A9);
  `Qt.rgba(_theme.base.r, …)` for translucent surfaces; cards tint with
  `_theme.base`; status drawer `_theme.surface2/1`; icons
  `_theme.text`; Canvas paints with `_theme.text` strokes.
- Wallpaper apply itself **feeds** the theme (matugen image) — picker is
  both consumer and producer of theme.

### 2.5 High-value features to port (wgpu)

1. **W1+W2** cover-flow grid + keyboard nav (wgpu: horizontal grid of
   image quads; focused card scaled 1.5×; skew via vertex transform or
   dropped; wheel-scroll accumulator + threshold + 150 ms throttle;
   keyboard nav = index state + centered focus).
2. **W6+W7** thumbnail cache + color markers (pure FS: `notify` watch
   thumbs dir, `image` crate resize for missing thumbs, `palette`/
   `color_thief` histogram for markers, maintain `colorMap` HashMap in
   Rust).
3. **W3** filter chips + HSV bucketing (port `getHexBucket` verbatim to
   Rust — pure function, unit-testable).
4. **W8+W9** apply via the wallpaper daemon (`nightforge-wallpaperd`,
   rework plan §4.4; `awww img` stopgap) + `matugen-sync.sh` after
   apply; monitor selection via `niri msg outputs`.
5. **W11** status drawer (progress text; spinner = animated arc in
   wgpu, or text only).

### 2.6 wgpu rendering approach (WallpaperPicker)

Scene graph rendered per frame:

```
WallpaperPickerScene
├── palette: Theme                       // from theme.rs, re-read each frame
├── filter: FilterBucket                 // 0=All..10=Search
├── search-query: String
├── grid: HorizontalGrid<WallpaperCard>  // image quads, focused card 1.5×
│   └── WallpaperCard { thumb: texture, accent: Color, is_video: bool }
├── FilterBar                            // chip quads (rounded rects) + label text
└── StatusDrawer                         // text quads + animated arc spinner
```

wgpu primitives used: text quads (glyph atlas via `cosmic-text`),
rounded-rect fills (instanced quads / SDF), linear/radial gradients
(vertex color or shader), image quads (thumbnails as textures), and a
canvas-style animation pass (spinner arc, focus transitions) driven by a
uniform clock — no layout/declarative layer between state and pixels.

Rust side:
```rust
struct WallpaperEntry { name: String, thumb: PathBuf, hex: Option<u32>, is_video: bool }
// notify watcher on thumbs dir → update grid model incrementally
// thumbnail worker: image crate resize → disk cache → texture upload
// color worker: palette/color_thief histogram per thumb → marker file
// apply(): socket command to nightforge-wallpaperd (awww img stopgap) + matugen-sync.sh
```

### 2.7 Data backend recommendation

**File watcher** (`notify` on thumbs dir + markers dir), **not** D-Bus.
Directory events are the entire signal surface; no polling needed for
arrival. Thumbnails: `image` crate resize + disk cache
(`~/.cache/nightforge/wallpaper_picker/thumbs`); art colors via
`palette`/`color_thief` histogram. Apply commands go through the
`wallpaper` topic of the event bus (§1.6) so the picker, daemon, and
matugen trigger stay in sync.

Apply = unix-socket command to the wallpaper daemon (or
`std::process::Command` → `awww img` + matugen-sync.sh as stopgap) —
same as QML `execDetached`, but now with exit-status handling (QML
fire-and-forget has zero error feedback; Rust can surface failures in
the status drawer — a real reliability win).

### 2.8 Port complexity: **High** (but decomposable)

- Phase A (Low): local grid + thumbs + apply + theme. ~90% of daily
  value.
- Phase B (Medium): filters + color markers + focus/keyboard polish.
- Phase C (High): online search (keep `ddg_search.sh` + python as
  subprocess; the incremental-arrival UI is the hard part, port
  `syncSearchModel` diffing to model splice).

---

## 3. Music Widget — `music/MusicPopup.qml` (1,473 ln) + `music_info.sh` (245 ln)

### 3.1 Feature inventory

| # | Feature | Details | Port worth |
|---|---|---|---|
| M1 | MPRIS state via playerctl | `music_info.sh` polls every 500 ms: title, artist, status, position/length (µs), percent, source (player name) | **High** (NF: swap to MPD) |
| M2 | Album art cache | md5(artUrl) → `$TMP_DIR/<hash>_art.jpg`; async subshell w/ lock file; placeholder blank; LRU 20; curl max-time 10; webp→jpg | **High** |
| M3 | **Art-derived colors** | magick histogram top-3 colors → `grad` (CSS gradient string); negate dominant → `textColor`; blur bg (`-blur 0x20 -brightness-contrast -30x-10`) | **High** (signature NightForge look) |
| M4 | Paused-position restore | `STATE_FILE` json pos/len; on pause keep last pos; on stop show last | High |
| M5 | Device/sink info | `wpctl inspect @DEFAULT_AUDIO_SINK@`: bluez→BT icon, usb/pci/system; device pill | Medium |
| M6 | Progress slider | seek w/ 2.5 s debounce; optimistic value set; masked gradient fill + catppuccin flow animation | **High** (simplify gradient) |
| M7 | Media controls | prev/play-pause/next via `player_control.sh`; pulse ripple; anti-jitter (playDebounce 1.5 s) | **High** |
| M8 | Marquee title | seamless clone-scroll, speed ∝ text width, pause 3 s | Medium |
| M9 | EQ (10-band) | `equalizer.sh` get/set_band/apply/preset; EasyEffects preset generation (python); pending flag; optimistic UI; lightning Canvas animation; presets grid | **M (later phase)** — `zbus` → EasyEffects, flat sliders, no lightning |
| M10 | Intro animation | 8-stage staggered entrance (main/cover/text/controls/sep/eq/…) | Medium (port simplified) |
| M11 | Animated chrome | rotating gradient border (MultiEffect mask), orbit circles, spinning cover w/ glow | Low (Qt-effects only; flat alternative) |

### 3.2 QML architecture

- Root `Item`; `musicData` / `eqData` JSON-ish property objects;
  `musicProc`/`eqProc` `Process` polled every 500 ms via Timer;
  `execCmd()` dynamic `Process` factory for fire-and-forget commands.
- **Anti-jitter pattern (important):** `userIsSeeking` +
  `userToggledPlay` flags + `lastEqUpdate` timestamp suppress poll
  overwrite of optimistic UI; debounce timers restore.
- `borderColors` parses `grad` hexes → 4-stop rotating border gradient;
  `dynamicTextColor` sanitizes shell-supplied color (regex `#RRGGBB`).
- Layout: cover art (circle, spin when playing), title/artist marquee,
  device pill + "VIA source", slider, time labels, controls, separator,
  EQ header + 10 vertical sliders + lightning Canvas + preset grid.
- `PresetButton` inline component (Rectangle+MouseArea).

### 3.3 Data flow

```
playerctl (MPRIS) ─500ms─> music_info.sh ─JSON─> musicData (QML object)
        │                          └─ art cache dir (hash files)
        └─ player_control.sh seek/next/prev/play-pause (debounced, latest-wins file+lock)
equalizer.sh state file ─500ms─> eqData
wpctl inspect @DEFAULT_AUDIO_SINK@ ──> deviceIcon/deviceName
```

NightForge swap: **MPD instead of MPRIS**. NF already has
`services/MpdClient.qml` (mpc poll every 1 s — 118-line simplified
popup). Rust: `mpd_client` (1.4.1) gives push `idle` notifications
(`player`, `mixer` subsystems) — strictly better than 500 ms polling.

### 3.4 Theme integration

- Every surface from `_theme`; art-derived overrides: `dynamicTextColor`
  (text legibility over art), `borderColors` (rotating gradient),
  blurred art as background layer (opacity 0.9 when playing).
- **Port rule:** theme = Matugen base; art colors = dynamic overlay.
  Keep the two-layer model — it's what makes the widget feel
  "alive" without custom theming.

### 3.5 High-value features to port (wgpu)

1. **M1–M5 data pipeline** (MPD + art cache + art-derived colors +
   paused restore + sink info) — one Rust `music.rs` module, all logic
   unit-testable.
2. **M6+M7** progress + controls with anti-jitter (port the lock
   pattern: local `seeking`/`toggled` flags suppress model pushback).
3. **M8** marquee (wgpu: glyph-atlas text quads with scroll offset per
   frame; clone-text trick works fine).
4. **M3** grad/textColor extraction: `image` crate decode + `palette`/
   `color_thief` histogram in Rust (drop magick for colors); backdrop
   blur via Niri compositor blur, pre-blurred image quad as fallback.
5. **M10** simplified intro (opacity/translate stagger).

### 3.6 wgpu rendering approach (MusicPopup)

Scene graph rendered per frame:

```
MusicPopupScene
├── palette: Theme
├── state: MusicState                // title, artist, status, percent, pos/len,
│                                    // art-path, grad colors, text-color, device
├── CoverArt                         // circular-clipped image quad, rotates when playing
├── TitleMarquee                     // glyph-atlas text quads, scroll offset per frame
├── InfoPill                         // rounded-rect quad + icon/text quads
├── ProgressSlider                   // gradient fill rect + handle; drag → seek, debounced
├── ControlRow                       // icon quads; ripple = opacity pulse on press
└── ArtBackground                    // image quad; Niri compositor blur or pre-blurred fallback
```

Rust:
```rust
struct MusicState { title, artist, status, percent, pos, len, art: PathBuf,
                    blur: PathBuf, grad: [Color;3], text_color: Color, device: ... }
// mpd_client::Client::idle loop → fetch → publish MusicState on socket bus (§1.6)
// art worker: filesystem-first art → image crate decode → cache → texture
// EQ: zbus → EasyEffects (later phase, flat sliders — no lightning)
```

### 3.7 Data backend recommendation

**MPD client (push)** for playback state — replaces both the 500 ms poll
and `player_control.sh`. Art/colors: filesystem-first album art +
`image` crate decode; art colors via `palette`/`color_thief` histogram;
driven by `idle` events instead of a timer. **EQ: `zbus` → EasyEffects**
over D-Bus (get/set bands, presets, bypass) — no Canvas lightning, flat
slider UI; a later phase once EasyEffects is confirmed in the audio
stack. Device/sink: `wpctl` is already fast (`timeout 0.5`) — poll
every 5 s, or subscribe via PipeWire (overkill v1).

If MPRIS parity is required for browsers (not in NF scope — MPD is the
stack), a `mpris` crate adapter can sit beside MPD later.

### 3.8 Port complexity: **Medium**

EQ (M9) deferred to a later phase → drops the only real complexity
(Canvas lightning + EasyEffects integration); when it lands it is
`zbus` → EasyEffects with flat sliders, no lightning. Core is a
well-bounded state machine + disk cache + 3 animations.

---

## 4. Network Widget — `network/NetworkPopup.qml` (2,367 ln) + 3 scripts

### 4.1 Feature inventory

| # | Feature | Details | Port worth |
|---|---|---|---|
| N1 | Unified ETH/WiFi/BT tabs | morphing highlight pill, mode persistence (`cache/mode` file), Tab-key cycling, first-load failsafe (1.5 s) | **High** |
| N2 | Panel logic backends | `eth_panel_logic.sh` / `wifi_panel_logic.sh` / `bluetooth_panel_logic.sh` — JSON status (present/power/connected/networks/devices), sysfs presence fast-path | **High** (keep scripts) |
| N3 | Power toggle | morphing power button (corner→bottom-right), pending-state + expected-value reconciliation w/ 8 s reset, per-mode | High |
| N4 | Connect flow | hold-to-connect (fill anim → trigger), wifi password prompt layer, busy/failed states, saved-network detection (nmcli), strongest-SSID highlight, connect sfx, 15 s busy timeout | **High** |
| N5 | Disconnect | hold-to-disconnect (wave fill), `disconnectingDevices` map, nmcli/bluetoothctl disconnect | High |
| N6 | Info view | connected device detail nodes (IP copy via wl-copy, signal/security/freq, BT battery/profile/MAC), scan action | Medium |
| N7 | Orbit visualization | 5 core slots, floating cards on parametric orbit (globalOrbitAngle 200 s), parent/child info nodes, radar rings, Canvas node-lines w/ noise strands | **Skip** (orbit/radar visuals skipped for value, not capability; flat list is fine) |
| N8 | List lock | `hoveredCardCount` suspends model sync while pointer over cards (prevents mid-click reflow) | **High** (UX correctness) |
| N9 | First-load cache | QSettings `QS_NetworkWidgetUnified` stores last JSONs → instant paint before poll | Medium |
| N10 | SFX | pw-play/paplay wavs on connect/disconnect/power/switch/error | Low (trivial) |
| N11 | Mode validation | present-flags drive tab visibility + active-mode fallback | High |

### 4.2 QML architecture

- Root `Item` + `Settings` cache; `Process` pollers (eth/wifi/bt)
  restarted by adaptive Timer (3 s idle / 1 s busy); `modeReader`
  polls `cache/mode` every 100 ms (file-based IPC for tab state).
- **State:** per-mode `power/powerPending/expectedPower/connected/list`
  + `firstLoad` flags; `busyTasks`/`disconnectingDevices` object maps;
  `currentCores[5]` + `coreVisualIndices` for orbit slots; `wifiList`/
  `btList`/`infoListModel` `ListModel`s.
- `processEthJson/WifiJson/BtJson` — the heart: JSON → state with
  optimistic-power reconciliation, connection detection (play connect
  sfx, clear busy), disconnect detection, list diffing (`syncModel`
  insert/move/update), list-lock deferral (`nextWifiList` etc.).
- `connectDevice(mode,id,macOrSsid,password)` — builds nmcli/
  bluetoothctl command, tracks busy/failed, cleanup on non-zero exit
  (delete failed wifi profile).
- Delegate `floatCard`: hold-fill state machine (`fillLevel`/`triggered`),
  wave Canvas, marquee, highlight (target/saved/paired), per-card
  `locksList` hooking N8.
- Power button, tabs, radar, orbit canvas, node-lines canvas all drive
  off `currentPower`/`currentConn`/`activeMode`/`introState`.

### 4.3 Data flow

```
nmcli/bluetoothctl ─3s poll─> *_panel_logic.sh ─JSON─> process*Json → state props
cache/mode file ─100ms poll─> activeMode
saved networks ─nmcli─> savedWifiNetworks[] (on tab enter)
actions ─execDetached─> nmcli device connect/disconnect | bluetoothctl | scripts
```

**File-based tab state** (`cache/mode`) is notable: the QML writes it
for persistence so next launch restores the tab. Keep in Rust (or
`~/.local/state/quickshell/network/mode`).

### 4.4 Theme integration

`_theme` colors everywhere; `activeColor` = per-mode accent (sapphire
for eth/wifi, mauve for BT); core/card gradients rendered as gradient
quads; red for danger (disconnect/failed). **Flat colors + Niri
compositor blur in the port** — no MultiEffect shadows (use solid alpha
quads); blur via `ext-background-effect` (xray default).

### 4.5 High-value features to port

1. **N1+N11** tabs + presence validation (pure state).
2. **N2** keep the three panel-logic scripts as subprocess JSON
   contracts (they already dodge D-Bus hangs with sysfs fast-paths).
3. **N3+N4+N5** power toggle + connect/disconnect flows with
   optimistic-state reconciliation and busy/failed UX. This is the
   functional core — port faithfully (incl. expectedPower reconciliation,
   failed-profile cleanup, 15 s busy timeout).
4. **N8** list-lock (defer model updates while pointer over a card).
5. **N9** last-JSON cache for instant paint.
6. **N10** sfx via `pw-play` (same call).

### 4.6 wgpu rendering approach (NetworkPopup)

Scene graph rendered per frame:

```
NetworkPopupScene
├── palette: Theme
├── active-mode: Mode (eth|wifi|bt)
├── devices: Vec<Device>             // switched by mode
├── connected: Option<Device>
├── power-on / power-pending: bool
├── busy-id / failed-id: Option<String>
│
├── TabBar                           // 3 tab quads + morphing highlight (animated rect)
├── PowerToggle                      // circle quad; pending → animated arc
├── DeviceList                       // vertical list of DeviceCard quads
│   └── DeviceCard: hold-to-activate (pressed duration), icon/text quads,
│       security subtext, busy dots, failed tint, hover list-lock gate
└── ConnectPanel                     // password input (text quad + caret blink)
```

Rust:
```rust
enum Mode { Eth, Wifi, Bt }
struct Device { id, ssid/name, mac, icon, signal, security, action,
                battery, profile, is_connected, is_info, is_actionable }
// control flows: zbus → NetworkManager (connect/disconnect/state/profiles)
// status: netlink (rtnetlink) for low-level link state; NM signals otherwise
// optimistic updates: set state immediately, reconcile on next NM event
// connect(): NM D-Bus call; track busy; on fail → delete profile (wifi)
```

### 4.7 Data backend recommendation

**NetworkManager D-Bus via `zbus` is primary** for control flows —
connect/disconnect, state, profiles, signal strength. **netlink
(rtnetlink) for low-level status only** (link up/down, carrier, speed).
Bash panel scripts stay as an interim v1 contract; the zbus layer
replaces them per-widget behind the same JSON shape. No `nmcli monitor`
needed — NM signals on D-Bus are the event source, published to the
socket bus (§1.6).

### 4.8 Port complexity: **High**

Not because of the data (trivial) but because of state-machine
surface: 3 modes × (power, connect, disconnect, pending reconciliation,
list diffing, first-load cache) + list-lock interaction. **Recommend
straight list UI (not orbit)** — cuts ~1,200 lines of Canvas/parametric
animation and keeps 100% of the functionality. Accept a flat-list look;
revisit visuals after core lands.

---

## 5. High-Value Feature Matrix (port vs skip)

| Feature | Widget | Effort | Value | Verdict |
|---|---|---|---|---|
| Local grid + thumbs + apply | Wallpaper | L | H | **Port (A)** |
| Color filters + markers | Wallpaper | M | H | **Port (B)** |
| Online DDG search | Wallpaper | H | M | Defer (C); scraper fragile |
| Video preview/apply | Wallpaper | H | M | Port later via wallpaper daemon (`libmpv`/`gstreamer`); awww can't |
| MPD state + art cache | Music | M | H | **Port (1)** |
| Art-derived colors/blur | Music | M | H | **Port (1)** |
| Progress + controls + anti-jitter | Music | M | H | **Port (1)** |
| Marquee / intro | Music | M | M | Port (2) |
| EQ (no lightning) | Music | M | M | Port later via `zbus` → EasyEffects |
| Tabs + power + connect flow | Network | H | H | **Port (3)** |
| Orbit/radar/Canvas visuals | Network | H | L | **Skip** |
| Info view + IP copy | Network | M | M | Port (3) |
| Theme watcher / perf-mode | Shared | L | H | **Port (0)** |
| Dir cache + event bus | Shared | L | H | **Port (0)** |

---

## 6. Port Priority Ranking

0. **Phase 0 spike — wgpu layer-shell proof (1 day):** one sctk
   layer-surface on Niri rendering text + rounded rect + gradient +
   animated quad; exclusive-zone/focus behavior verified. This is the
   gate for the whole port (rework plan §4.1).
1. **Phase 0 — Shared plumbing (0.5–1 wk):** `theme.rs` watcher,
   `QsDirs`, **unix-socket event bus** (§1.6; dispatcher bridges
   `/tmp/qs_widget_state`), scene scaffolding + Scaler. Unlocks
   everything; replaces Quickshell shell.qml routing incrementally.
2. **Phase 1 — Music core (1–2 wk):** MPD client + art pipeline +
   cover/progress/controls. Smallest surface, highest polish-per-line,
   proves the theme+image pipeline end to end.
3. **Phase 2 — Wallpaper local (2 wk):** grid + thumbs + apply + filters
   (A+B). Daily-driver frequency makes it the second-biggest win.
4. **Phase 3 — Network (2–3 wk):** tabs + list + connect flows. Largest
   state surface; do last so Phase 0–2 patterns are proven.
5. **Deferred:** DDG search (C), EQ (lands later via `zbus` →
   EasyEffects), orbit visuals, video wallpapers (lands via the
   wallpaper/video daemon).

**Cutover rule (daily driver):** each phase ships behind the
`/tmp/qs_widget_state` router — keybind points at `qs_manager.sh`, which
can be switched per-widget between Quickshell and the Rust binary
(`exec:` slot or a `nightforge-widgets` dispatcher). Quickshell config
stays installed; rollback = one keybind edit.

---

## 7. Risk Notes (NightForge daily driver)

| Risk | Severity | Mitigation |
|---|---|---|
| **wgpu engineering complexity** — shaders, text rendering, surface control, frame loop are all ours (no declarative layer) | **High** | Phase 0 spike FIRST: one sctk layer-surface on Niri (text + rect + gradient + animated quad); only proceed if focus/exclusive-zones behave. Mitigate with `cosmic-text` glyph atlas + instanced quad batching; keep Quickshell shell until wgpu covers the surface |
| **Video wallpaper instability** — `libmpv`/`gstreamer` decode per output, hot-plug, throttle logic can glitch on the daily driver | Med | Separate daemon (rework plan §4.4) so a crash never takes the shell down; pause-when-occluded + battery throttling; awww fallback until the daemon is stable |
| **Blur** — replaced by Niri compositor blur (`ext-background-effect`, xray default); pre-render/magick blur is fallback only (album-art backdrop) | Low | Perf-mode=low toggles the compositor effect off; verify xray vs non-xray cost per surface |
| **Canvas 2D effects (lightning, orbits)** — no longer a capability gap; wgpu does canvas-style animation | Low | Still don't port those effects (see matrix) — skipped for value, not capability |
| **Bash → Rust process contract drift** — panel scripts return JSON; Rust must parse strictly | Med | Pin a JSON schema per script; add `serde_json` deserializers + unit tests mirroring `processEthJson` etc.; run scripts unchanged in v1 |
| **MPD vs MPRIS** — reference = playerctl; NF = MPD | Low | NF already committed to MPD (`mpd.service`, `MpdClient.qml`). Use `mpd_client` crate `idle` push. Don't add MPRIS in v1 |
| **Polling behavior change** — QML polls per-widget; Rust event bus centralizes | Low | Go daemon already centralizes; keep 3 s cadence so behavior parity holds |
| **Quickshell fallback regression** — dual-shell edit risk | Low | Read-only pass so far; switch router per-widget; keep `qs_manager.sh` as single source of widget routing |
| **No-push constraint** — S187 ops | — | Nothing staged; this doc is analysis only |

---

## 8. Open Questions (for pi)

1. wgpu layer-shell spike (Phase 0) — confirm the 1-day budget? (rework
   plan §4.1 gate)
2. Niri compositor blur: xray default for all panels, or per-surface
   choice (xray vs non-xray) in config?
3. Online search: DDG scraper stays bash+python (kept as subprocess) —
   OK with IP/ToS surface, or drop entirely?
4. Video wallpapers: confirm `libmpv` vs `gstreamer` as the decode
   backend for the wallpaper/video daemon?
5. EQ: is EasyEffects part of the NightForge audio stack going forward?
   (If yes, port EQ via `zbus` — no lightning — as a later phase.)

---

*Sources: `~/Github/nixos-configuration/config/sessions/hyprland/scripts/quickshell/`
(WallpaperPicker.qml 1,826 ln; MusicPopup.qml 1,473 ln + music_info.sh
245 ln + equalizer.sh + player_control.sh; NetworkPopup.qml 2,367 ln +
{eth,wifi,bluetooth}_panel_logic.sh; Caching.qml; Scaler.qml;
MatugenColors.qml; Config.qml; WindowRegistry.js; watchers/{audio,
battery,bt,kb,network}_{fetch,wait}.sh; wallpaper/{ddg_search.sh,
get_ddg_links.py,matugen_reload.sh}; caching.sh). NightForge current
state: `~/Github/nightforge/scripts/qs-watcher/main.go`,
`dotfiles/quickshell/`, `scripts/matugen-sync.sh`,
`dotfiles/niri/.config/niri/`.*
