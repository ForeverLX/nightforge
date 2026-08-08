# Ghostty API Research: CLI/TUI Harness Integration

**Researched:** 2026-07-19  
**Sources:** ghostty.org/docs, ghostty-org-ghostty.mintlify.app, deepwiki.com/ghostty-org/ghostty

---

## 1. What Ghostty Is (And Is Not)

**Ghostty is a terminal emulator** — not an agent framework, not a CLI harness runtime. It is a fast, feature-rich, cross-platform terminal emulator written in Zig by Mitchell Hashimoto, designed around three goals: native UI, feature-richness, and speed.

Key identity points:
- **Platform-native**: macOS GUI in Swift/AppKit, Linux GUI in Zig + GTK4 C API
- **Shared core**: Both frontends consume a common C-ABI-compatible library called **libghostty**
- **Not a stable embedding library yet**: The C API powers the macOS app today but is explicitly marked unstable for general-purpose embedding. A stable libghostty is on the roadmap.
- **Not an agent harness**: Ghostty provides terminal emulation, PTY I/O, GPU-accelerated rendering, and font management — not agent orchestration, tool calling, or workflow management.

**Verdict for harness integration**: Ghostty is suitable as a **terminal rendering/PTY backend** for a CLI/TUI harness (e.g., embedding a terminal widget in a dev tool), but NOT as a general agent runtime. The libghostty C API could power the TUI display layer of an AI agent harness that needs a real terminal emulator embedded.

---

## 2. Key API Surfaces for Harness Integration

### 2.1 libghostty C API (ghostty.h)

The primary integration surface. All handles are opaque void pointers:

```c
typedef void* ghostty_app_t;        // Application instance (global state)
typedef void* ghostty_config_t;     // Configuration
typedef void* ghostty_surface_t;    // Terminal surface
typedef void* ghostty_inspector_t;  // Inspector/debugger
```

**Lifecycle** (embedding flow):
1. `ghostty_init(argc, argv)` — global state (allocators, logging)
2. `ghostty_config_new()` → load files → `ghostty_config_finalize()`
3. `ghostty_app_new(&runtime_config, config)` — creates app with callbacks
4. `ghostty_surface_new(app, &surface_config)` — creates a terminal surface
5. Loop: `ghostty_app_tick(app)` + `ghostty_surface_draw(surface)`
6. Cleanup: free surface → free app → free config

**Runtime callbacks** the host must implement:
- `wakeup_cb` — signal event loop to process pending work
- `action_cb` — handle terminal actions (bell, title change, notifications)
- `read_clipboard_cb` / `write_clipboard_cb` — clipboard integration
- `close_surface_cb` — handle surface close

**Platform-specific surface config** — Linux uses:
```c
ghostty_surface_config_s config = {
    .platform_tag = GHOSTTY_PLATFORM_LINUX,
    // GTK integration via OpenGL
    // Fontconfig/FreeType for fonts
};
```
MacOS uses Metal/SwiftUI, iOS has experimental support.

**Input forwarding** — host forwards keyboard and mouse:
- `ghostty_surface_key(surface, key)` — keyboard events
- `ghostty_surface_mouse_button(...)` — mouse clicks
- `ghostty_surface_mouse_pos(...)` — mouse movement
- `ghostty_surface_scroll(...)` — scroll events

**Clipboard** — the host provides read/write callbacks; `supports_selection_clipboard` flag enables X11 selection support.

### 2.2 Architecture Layers (from codebase)

| Layer | Role | Key Files |
|---|---|---|
| **Platform UI** | Native window management, GTK/Swift glue | `src/apprt/gtk.zig`, `macos/Sources/*.swift` |
| **Application Runtime (apprt)** | Platform abstraction, action dispatch | `src/apprt/embedded.zig`, `src/apprt/action.zig` |
| **Core Application** | Surface management, font caching | `src/App.zig`, `src/Surface.zig` |
| **Configuration** | Parsing, validation, derivation | `src/config/Config.zig`, `src/config.zig` |
| **Terminal Emulation** | VT sequence processing, screen state | `src/terminal/main.zig` |
| **I/O and Process** | PTY communication, event loop | `src/termio.zig`, `src/pty.zig` |
| **Rendering Pipeline** | Multi-threaded GPU rendering | `src/renderer.zig` |

### 2.3 Threading Model

Three dedicated threads per surface:
1. **Main/UI Thread**: UI event loop, user input
2. **I/O Thread**: PTY read/write, VT emulation
3. **Renderer Thread**: GPU command submission, frame timing

This matters for harness integration: the embedding app must provide a compatible threading model and safely forward events to the correct thread.

### 2.4 Configuration System

- `~/.config/ghostty/config` loaded automatically
- Programmatic config via `ghostty_config_load_file()` or `ghostty_config_load_default_files()`
- Diagnostics: `ghostty_config_diagnostics_count()` / `ghostty_config_get_diagnostic()` — for surfacing config errors in the host UI
- Hundreds of configuration options (keybindings, themes, fonts, terminal behavior)

---

## 3. Build Requirements

### 3.1 Zig Compiler

Ghostty pins to a **specific Zig version** per release:

| Ghostty | Zig |
|---|---|
| 1.0.x | 0.13.0 |
| 1.1.x | 0.13.0 |
| 1.2.x | 0.14.1 |
| 1.3.x | 0.15.2 |
| tip | 0.15.2 |

Only the listed Zig version is guaranteed to work — Zig is still rapidly evolving.

### 3.2 Build Command

```bash
git clone https://github.com/ghostty-org/ghostty
cd ghostty
zig build -Doptimize=ReleaseFast
```

Output: `zig-out/bin/ghostty` (Linux) or `zig-out/Ghostty.app` (macOS).

Debug builds exist (`omit -Doptimize`) but are >100x slower.

### 3.3 Linux Dependencies

Required: `gtk4`, `libadwaita`, `gtk4-layer-shell`, `pkg-config`/`pkgconf`, `gettext`

Per-distribution packages:

| Distro | Command |
|---|---|
| **Arch** | `pacman -S gtk4 gtk4-layer-shell libadwaita gettext` |
| **Debian/Ubuntu** | `apt install libgtk-4-dev libgtk4-layer-shell-dev libadwaita-1-dev gettext libxml2-utils` |
| **Fedora** | `dnf install gtk4-devel gtk4-layer-shell-devel zig libadwaita-devel gettext` |
| **Alpine** | `apk add gtk4.0-dev libadwaita-dev pkgconf ncurses gettext` |
| **openSUSE** | `zypper install gtk4-devel libadwaita-devel pkgconf ncurses-devel zig gettext` |
| **Gentoo** | `emerge -av libadwaita gtk blueprint-compiler gettext` |

Note: On distros without `gtk4-layer-shell` (Ubuntu 24.04, Debian 12), use `-fno-sys=gtk4-layer-shell` to compile it from source.

### 3.4 Nix Build Environment

The official build environment is Nix-based — it runs CI and builds release artifacts. Nix is recommended but not required.

### 3.5 Source Tarball vs Git Checkout

- **Source tarballs** (recommended for end users): preprocessed, fewer deps needed
- **Git checkout** (developers/contributors): requires additional dev dependencies

Tarballs at `https://release.files.ghostty.org/VERSION/ghostty-VERSION.tar.gz`

---

## 4. Linux Integration Points

### 4.1 GTK4 + Adwaita

Ghostty on Linux uses GTK4 as its UI toolkit with optional Adwaita theming. Minimum versions:

| Ghostty | GTK | Adwaita |
|---|---|---|
| 1.2.x | 4.14 | 1.5 |
| 1.1.x | 4.8 | 1.2 |

The GTK frontend is written entirely in Zig using the GTK4 C API (not GObject introspection). This means an embedding host must also use GTK4 or provide its own rendering context.

### 4.2 Wayland & X11

Ghostty supports both display protocols. `gtk4-layer-shell` provides layer-shell protocol support for desktop environments that support it (e.g., drop-down terminal mode).

### 4.3 Rendering

- **OpenGL** via GTK's GL area widget
- Font rendering via **Fontconfig** + **FreeType**
- Full GPU-accelerated rendering pipeline with dedicated renderer thread

### 4.4 Systemd & D-Bus

Ghostty has explicit systemd/D-Bus integration support (`/docs/linux/systemd`). For a harness embedding Ghostty, D-Bus notification integration and systemd service files are available.

### 4.5 Embedded Mode

The `apprt/embedded.zig` module exposes a C-friendly interface for embedding Ghostty into non-GTK applications. The embedded runtime provides:
- Terminal emulation without a full window
- Programmatic I/O reading/writing
- Surface creation with custom rendering callbacks

This is the most relevant path for a CLI/TUI harness: use the embedded runtime to get a headless terminal surface, then render its output to a custom TUI widget (e.g., via ratatui or bubbletea).

### 4.6 Vouched Contributor System

The project uses a "vouch" system (`.github/VOUCHED.td`, discussion-managed) for PR/issue triage. Not directly relevant to harness integration but noteworthy for contributing patches upstream.

---

## 5. Testing & Quality Infrastructure

- **Zig built-in test framework**: `zig build test` runs unit tests
- **CI via GitHub Actions + Nix**: cross-platform matrix builds
- **AFL++ fuzzing**: VT sequence parser fuzzing in `pkg/afl++/`
- **Docker-based testing**: Debian container in `src/build/docker/`
- **Release pipeline**: automated tag-based releases, `tip` releases for latest HEAD
- **Snap packaging**: CI workflow for snap builds
- **Static analysis**: Zig compiler's own safety checks (runtime bounds checking in debug mode)

---

## 6. Suitability as a Harness Runtime

### Strong fit for:
- **Embedded terminal widget** in a TUI app — the libghostty embedded API can provide real terminal emulation with proper PTY, VT sequence handling, and GPU rendering
- **CLI tool with terminal output capture** — the I/O thread model separates terminal I/O from rendering, making it feasible to capture output programmatically
- **Cross-platform TUI harness** — libghostty runs on macOS, Linux, and iOS (experimental)

### Poor fit for:
- **Agent orchestration runtime** — Ghostty has no concept of agents, tool calling, LLM integration, or workflow management
- **Lightweight PTY alone** — if you just need a PTY, Ghostty's full rendering pipeline is overkill; use `forkpty()` or a library like `libvterm`
- **Non-GPU environments** — rendering depends on Metal (macOS) or OpenGL (Linux)

### Integration approach for a CLI/TUI harness:
1. Link against `libghostty` via the C ABI
2. Use `apprt/embedded.zig` for headless terminal surfaces
3. Route `ghostty_surface_draw()` output to your TUI framework's rendering loop
4. Forward stdin/stdout through the PTY I/O thread
5. Implement minimal runtime callbacks (wakeup, action, clipboard)

---

## Key Source Files for Integration

| File | Purpose |
|---|---|
| `include/ghostty.h` | Public C API header (all host-facing functions) |
| `src/apprt/embedded.zig` | Headless embedded runtime |
| `src/App.zig` | Global state, surface management |
| `src/Surface.zig` | Per-surface lifecycle |
| `src/config/Config.zig` | Configuration parsing |
| `src/terminal/main.zig` | Terminal emulation core |
| `src/termio.zig` | PTY I/O event loop |
| `src/renderer.zig` | GPU rendering pipeline |
| `build.zig` | Build system entry point |
