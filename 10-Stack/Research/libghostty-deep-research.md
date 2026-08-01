# libghostty Deep Research: Embedding Terminal Emulation in GN Harness

**Researched:** 2026-07-22
**Sources:** ghostty.h (C API header), libghostty-vt Doxygen docs, libghostty-rs (Rust bindings), godotty (Rust embedding), moai-studio (multi-pane terminal), awesome-libghostty (ecosystem)

---

## Critical Distinction: Two Libraries

There are **two distinct C libraries** in the Ghostty ecosystem. Confusing them is the #1 integration mistake:

| Library | Scope | Use Case | Crate |
|---|---|---|---|
| **libghostty** (`ghostty.h`) | Full app runtime: config, surfaces, PTY, GPU rendering, windowing | Embedding a complete terminal app (macOS/iOS only today) | `ghostty-sys` (archived, unmaintained) |
| **libghostty-vt** (`vt.h`) | VT parser + terminal state + input encoding only | Embedding terminal emulation in your own renderer | `libghostty-vt-sys` → `libghostty-vt` (active, maintained) |

**For GN Harness, we need `libghostty-vt`** — the extracted VT engine. We provide our own rendering (ratatui or custom). The full `libghostty` embedding API is macOS/iOS-only today and requires GTK4 on Linux (which we don't want).

---

## C API Reference

### libghostty-vt Core Types (from Doxygen)

```c
// Opaque handles — all created with _new(), freed with _free()
typedef struct GhosttyTerminalImpl*    GhosttyTerminal;
typedef struct GhosttyRenderStateImpl* GhosttyRenderState;
typedef struct GhosttyKeyEncoderImpl*  GhosttyKeyEncoder;
typedef struct GhosttyKeyEventImpl*    GhosttyKeyEvent;
typedef struct GhosttyMouseEncoderImpl* GhosttyMouseEncoder;
typedef struct GhosttyMouseEventImpl*  GhosttyMouseEvent;

// Result type
typedef int GhosttyResult;  // GHOSTTY_SUCCESS = 0
```

### Terminal API

```c
// Lifecycle
GhosttyResult ghostty_terminal_new(
    const GhosttyAllocator *allocator,  // NULL = default
    GhosttyTerminal *out_terminal,
    GhosttyTerminalOptions options       // .cols, .rows, .max_scrollback
);
void ghostty_terminal_free(GhosttyTerminal terminal);

// VT data input — feed PTY output here
void ghostty_terminal_vt_write(
    GhosttyTerminal terminal,
    const uint8_t *data,
    size_t len
);

// Configure effect callbacks
void ghostty_terminal_set(
    GhosttyTerminal terminal,
    GhosttyTerminalOption option,   // GHOSTTY_TERMINAL_OPT_*
    const void *value               // callback pointer or config value
);

// Query terminal state
GhosttyResult ghostty_terminal_get(
    GhosttyTerminal terminal,
    GhosttyTerminalData data,       // GHOSTTY_TERMINAL_DATA_*
    void *out_value
);

// Resize
void ghostty_terminal_resize(
    GhosttyTerminal terminal,
    uint16_t cols,
    uint16_t rows
);

// Grid access for selection
GhosttyResult ghostty_terminal_grid_ref(
    GhosttyTerminal terminal,
    GhosttyPoint point,
    GhosttyGridRef *out_ref
);

// Selection
GhosttyResult ghostty_terminal_set(
    GhosttyTerminal terminal,
    GHOSTTY_TERMINAL_OPT_SELECTION,
    const GhosttySelection *selection
);
```

### TerminalOptions

```c
typedef struct {
    uint16_t cols;           // columns (e.g., 80)
    uint16_t rows;           // rows (e.g., 24)
    uint32_t max_scrollback; // max scrollback lines (0 = none)
} GhosttyTerminalOptions;
```

### Terminal Effect Callbacks

Registered via `ghostty_terminal_set()` with these options:

| Option | Callback Type | Trigger |
|---|---|---|
| `GHOSTTY_TERMINAL_OPT_WRITE_PTY` | `GhosttyTerminalWritePtyFn` | Query responses to write back to PTY |
| `GHOSTTY_TERMINAL_OPT_BELL` | `GhosttyTerminalBellFn` | BEL character (0x07) |
| `GHOSTTY_TERMINAL_OPT_TITLE_CHANGED` | `GhosttyTerminalTitleChangedFn` | OSC 0 / OSC 2 title change |
| `GHOSTTY_TERMINAL_OPT_PWD_CHANGED` | `GhosttyTerminalPwdChangedFn` | OSC 7 / OSC 9 / OSC 1337 pwd change |
| `GHOSTTY_TERMINAL_OPT_ENQUIRY` | `GhosttyTerminalEnquiryFn` | ENQ character (0x05) |
| `GHOSTTY_TERMINAL_OPT_XTVERSION` | `GhosttyTerminalXtversionFn` | XTVERSION query (CSI > q) |
| `GHOSTTY_TERMINAL_OPT_SIZE` | `GhosttyTerminalSizeFn` | XTWINOPS size query (CSI 14/16/18 t) |
| `GHOSTTY_TERMINAL_OPT_COLOR_SCHEME` | `GhosttyTerminalColorSchemeFn` | Color scheme query (CSI ? 996 n) |
| `GHOSTTY_TERMINAL_OPT_DEVICE_ATTRIBUTES` | `GhosttyTerminalDeviceAttributesFn` | Device attributes query (CSI c) |
| `GHOSTTY_TERMINAL_OPT_USERDATA` | (void pointer) | Attached userdata passed to all callbacks |

**Critical:** All callbacks are invoked **synchronously** during `ghostty_terminal_vt_write()`. They must NOT call `ghostty_terminal_vt_write()` on the same terminal (no reentrancy). They must not block or do expensive work.

### Render State API

```c
// Lifecycle
GhosttyResult ghostty_render_state_new(
    const GhosttyAllocator *allocator,
    GhosttyRenderState *out_state
);
void ghostty_render_state_free(GhosttyRenderState state);

// Update from terminal (requires exclusive access to terminal)
GhosttyResult ghostty_render_state_update(
    GhosttyRenderState state,
    GhosttyTerminal terminal
);

// Query dirty state
GhosttyResult ghostty_render_state_get(
    GhosttyRenderState state,
    GhosttyRenderStateData data,  // GHOSTTY_RENDER_STATE_DATA_*
    void *out_value
);

// Row iteration
GhosttyResult ghostty_render_state_row_iterator_new(
    const GhosttyAllocator *allocator,
    GhosttyRenderStateRowIterator *out_iter
);
GhosttyResult ghostty_render_state_row_cells_new(
    const GhosttyAllocator *allocator,
    GhosttyRenderStateRowCells *out_cells
);
```

**Dirty Tracking:**
- `GHOSTTY_RENDER_STATE_DATA_DIRTY` → `GHOSTTY_RENDER_STATE_DIRTY_FALSE` / `PARTIAL` / `FULL`
- Per-row dirty flags for partial redraws
- Caller must reset both global and per-row dirty flags after rendering

**Cell Data Available:**
- Graphemes (codepoints per cell)
- Styles (foreground, background, underline, italic, bold, etc.)
- Cursor position and visual style (bar/block/underline/hollow)
- Colors (background, foreground, palette)

### Key Encoding API

```c
// Lifecycle
GhosttyResult ghostty_key_encoder_new(
    const GhosttyAllocator *allocator,
    GhosttyKeyEncoder *out_encoder
);
void ghostty_key_encoder_free(GhosttyKeyEncoder encoder);

// Configure
void ghostty_key_encoder_setopt(
    GhosttyKeyEncoder encoder,
    GhosttyKeyEncoderOption option,
    const void *value
);
void ghostty_key_encoder_setopt_from_terminal(
    GhosttyKeyEncoder encoder,
    GhosttyTerminal terminal  // syncs cursor key mode, Kitty flags, etc.
);

// Encode key event
GhosttyResult ghostty_key_encoder_encode(
    GhosttyKeyEncoder encoder,
    GhosttyKeyEvent event,
    char *out_buf,
    size_t out_buf_size,
    size_t *out_len
);

// Key event lifecycle
GhosttyResult ghostty_key_event_new(const GhosttyAllocator*, GhosttyKeyEvent*);
void ghostty_key_event_free(GhosttyKeyEvent event);

// Key event setters/getters
void ghostty_key_event_set_action(GhosttyKeyEvent, GhosttyKeyAction);
void ghostty_key_event_set_key(GhosttyKeyEvent, GhosttyKey);
void ghostty_key_event_set_mods(GhosttyKeyEvent, GhosttyMods);
void ghostty_key_event_set_consumed_mods(GhosttyKeyEvent, GhosttyMods);
void ghostty_key_event_set_composing(GhosttyKeyEvent, bool);
void ghostty_key_event_set_utf8(GhosttyKeyEvent, const char *utf8, size_t len);
void ghostty_key_event_set_unshifted_codepoint(GhosttyKeyEvent, uint32_t);
```

**Encoder Options:**
- `GHOSTTY_KEY_ENCODER_OPT_CURSOR_KEY_APPLICATION` — application cursor keys
- `GHOSTTY_KEY_ENCODER_OPT_KITTY_FLAGS` — Kitty keyboard protocol flags
- `GHOSTTY_KEY_ENCODER_OPT_ALT_ESC_PREFIX` — Alt as ESC prefix
- `GHOSTTY_KEY_ENCODER_OPT_MODIFY_OTHER_KEYS_STATE_2` — modifyOtherKeys mode 2

**Key Action:** `RELEASE=0`, `PRESS=1`, `REPEAT=2`

**Modifiers (bitmask):**
```
SHIFT=1, CTRL=2, ALT=4, SUPER=8, CAPS=16, NUM=32,
SHIFT_RIGHT=64, CTRL_RIGHT=128, ALT_RIGHT=256, SUPER_RIGHT=512
```

### Mouse Encoding API

```c
// Lifecycle
GhosttyResult ghostty_mouse_encoder_new(const GhosttyAllocator*, GhosttyMouseEncoder*);
void ghostty_mouse_encoder_free(GhosttyMouseEncoder encoder);

// Configure
void ghostty_mouse_encoder_setopt(GhosttyMouseEncoder, GhosttyMouseEncoderOption, const void*);
void ghostty_mouse_encoder_setopt_from_terminal(GhosttyMouseEncoder, GhosttyTerminal);

// Encode
GhosttyResult ghostty_mouse_encoder_encode(
    GhosttyMouseEncoder encoder,
    GhosttyMouseEvent event,
    char *out_buf, size_t out_buf_size, size_t *out_len
);

// Event lifecycle
GhosttyResult ghostty_mouse_event_new(const GhosttyAllocator*, GhosttyMouseEvent*);
void ghostty_mouse_event_free(GhosttyMouseEvent event);

// Event setters
void ghostty_mouse_event_set_action(GhosttyMouseEvent, GhosttyMouseAction);
void ghostty_mouse_event_set_button(GhosttyMouseEvent, GhosttyMouseButton);
void ghostty_mouse_event_set_mods(GhosttyMouseEvent, GhosttyMods);
void ghostty_mouse_event_set_position(GhosttyMouseEvent, GhosttyMousePosition);
```

**Mouse Actions:** `PRESS=0`, `RELEASE=1`, `MOTION=2`

**Mouse Tracking Modes:** `NONE=0`, `X10=1`, `NORMAL=2`, `BUTTON=3`, `ANY=4`

**Mouse Formats:** X10, UTF-8, SGR, URxvt, SGR-Pixels

**Encoder Size (for coordinate mapping):**
```c
typedef struct {
    size_t size;           // sizeof(GhosttyMouseEncoderSize)
    uint32_t screen_width;
    uint32_t screen_height;
    uint32_t cell_width;
    uint32_t cell_height;
} GhosttyMouseEncoderSize;
```

### Focus Encoding API

```c
GhosttyResult ghostty_focus_encoder_new(const GhosttyAllocator*, GhosttyFocusEncoder*);
void ghostty_focus_encoder_free(GhosttyFocusEncoder);
GhosttyResult ghostty_focus_encoder_encode(
    GhosttyFocusEncoder, bool focused, char *out, size_t out_size, size_t *out_len
);
```

### Full libghostty Embedding API (ghostty.h)

This is the **full app runtime** (macOS/iOS only on Linux requires GTK4). Included for completeness:

```c
// Initialization
int ghostty_init(uintptr_t argc, char **argv);
ghostty_info_s ghostty_info(void);

// Configuration
ghostty_config_t ghostty_config_new(void);
void ghostty_config_free(ghostty_config_t);
ghostty_config_t ghostty_config_clone(ghostty_config_t);
void ghostty_config_load_cli_args(ghostty_config_t);
void ghostty_config_load_file(ghostty_config_t, const char*);
void ghostty_config_load_default_files(ghostty_config_t);
void ghostty_config_load_recursive_files(ghostty_config_t);
void ghostty_config_finalize(ghostty_config_t);
bool ghostty_config_get(ghostty_config_t, void*, const char*, uintptr_t);
ghostty_input_trigger_s ghostty_config_trigger(ghostty_config_t, const char*, uintptr_t);
uint32_t ghostty_config_diagnostics_count(ghostty_config_t);
ghostty_diagnostic_s ghostty_config_get_diagnostic(ghostty_config_t, uint32_t);

// Application
ghostty_app_t ghostty_app_new(const ghostty_runtime_config_s*, ghostty_config_t);
void ghostty_app_free(ghostty_app_t);
void ghostty_app_tick(ghostty_app_t);
bool ghostty_app_key(ghostty_app_t, ghostty_input_key_s);
void ghostty_app_set_color_scheme(ghostty_app_t, ghostty_color_scheme_e);

// Surface (terminal instance)
ghostty_surface_config_s ghostty_surface_config_new(void);
ghostty_surface_t ghostty_surface_new(ghostty_app_t, const ghostty_surface_config_s*);
void ghostty_surface_free(ghostty_surface_t);
void ghostty_surface_refresh(ghostty_surface_t);
void ghostty_surface_draw(ghostty_surface_t);
void ghostty_surface_set_size(ghostty_surface_t, uint32_t, uint32_t);
void ghostty_surface_set_focus(ghostty_surface_t, bool);
bool ghostty_surface_key(ghostty_surface_t, ghostty_input_key_s);
void ghostty_surface_mouse_button(ghostty_surface_t, ...);
void ghostty_surface_mouse_pos(ghostty_surface_t, double, double, ghostty_input_mods_e);
void ghostty_surface_mouse_scroll(ghostty_surface_t, double, double, ghostty_input_scroll_mods_t);
void ghostty_surface_text(ghostty_surface_t, const char*, uintptr_t);

// Runtime callbacks (host must implement)
typedef void (*ghostty_runtime_wakeup_cb)(void*);
typedef bool (*ghostty_runtime_action_cb)(ghostty_app_t, ghostty_target_s, ghostty_action_s);
typedef bool (*ghostty_runtime_read_clipboard_cb)(void*, ghostty_clipboard_e, void*);
typedef void (*ghostty_runtime_write_clipboard_cb)(void*, ghostty_clipboard_e, const ghostty_clipboard_content_s*, size_t, bool);
typedef void (*ghostty_runtime_close_surface_cb)(void*, bool);

typedef struct {
    void* userdata;
    bool supports_selection_clipboard;
    ghostty_runtime_wakeup_cb wakeup_cb;
    ghostty_runtime_action_cb action_cb;
    ghostty_runtime_read_clipboard_cb read_clipboard_cb;
    ghostty_runtime_write_clipboard_cb write_clipboard_cb;
    ghostty_runtime_close_surface_cb close_surface_cb;
} ghostty_runtime_config_s;
```

**⚠️ WARNING:** The full `ghostty.h` embedding API is NOT portable to Linux without GTK4. The surface rendering uses platform-specific backends (Metal on macOS, OpenGL via GTK on Linux). For headless/custom rendering, use `libghostty-vt` instead.

---

## Embedded Runtime (libghostty-vt)

### Architecture

libghostty-vt is the **extracted VT engine** from Ghostty. It handles:
- VT escape sequence parsing
- Terminal state (screen, scrollback, cursor, styles, modes)
- Input encoding (keyboard, mouse, focus)
- Render state tracking (dirty regions, cell data)
- Kitty graphics protocol (optional)
- OSC/SGR parsers
- Unicode utilities

It does **NOT** handle:
- Windowing
- Rendering (GPU/OpenGL/Metal)
- PTY management
- Process spawning
- Font loading

### Build Requirements

- **Zig 0.15.2** on PATH (Ghostty 1.3.x pins this version)
- `libghostty-vt-sys` build script auto-fetches Ghostty source from a pinned commit
- Set `GHOSTTY_SOURCE_DIR` for local Ghostty checkout
- Static linking by default (`libghostty-vt.a`)
- Optional dynamic linking via `libghostty-vt-sys/link-dynamic` feature

---

## Surface Lifecycle (Per-Pane Pattern)

For GN Harness, each pane owns:

```
┌─────────────────────────────────────┐
│ Pane (Rust struct)                   │
│                                      │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Terminal      │  │ RenderState  │ │
│  │ (VT state)    │  │ (screen      │ │
│  │               │←→│  snapshot)   │ │
│  └──────┬───────┘  └──────┬───────┘ │
│         │                  │         │
│  ┌──────┴───────┐  ┌──────┴───────┐ │
│  │ KeyEncoder   │  │ MouseEncoder │ │
│  │ (key→VT seq) │  │ (mouse→VT   │ │
│  │              │  │  seq)        │ │
│  └──────────────┘  └──────────────┘ │
│                                      │
│  PTY (portable-pty)                  │
│  ├── Writer (stdin → shell)          │
│  └── Reader (shell → vt_write)       │
└─────────────────────────────────────┘
```

### Lifecycle Steps

```rust
// 1. Create terminal
let terminal = Terminal::new(TerminalOptions {
    cols: 80,
    rows: 24,
    max_scrollback: 10_000,
})?;

// 2. Register effect callbacks
terminal.on_pty_write(|_term, data| {
    // Write query responses back to PTY
    pty_writer.write_all(data);
})?;
terminal.on_bell(|_term| {
    // Handle bell
})?;
terminal.on_title_changed(|_term| {
    // Update tab title
})?;

// 3. Spawn PTY with shell
let pty = portable_pty::native_pty_system();
let pair = pty.openpty(PtySize { rows: 24, cols: 80, .. })?;
let mut child = Command::new("bash")
    .args(["-l"])
    .env("TERM", "xterm-256color")
    .spawn_on_pty(pair.slave)?;

// 4. Main loop
loop {
    // Drain PTY output → terminal
    let reader = pair.master.try_clone_reader()?;
    let mut buf = [0u8; 4096];
    loop {
        match reader.read(&mut buf) {
            Ok(0) => break,
            Ok(n) => terminal.vt_write(&buf[..n]),
            Err(_) => break,
        }
    }

    // Update render state
    let mut render_state = RenderState::new()?;
    render_state.update(&terminal)?;

    // Read dirty state
    let dirty = render_state.get(GHOSTTY_RENDER_STATE_DATA_DIRTY)?;

    // Render changed cells...
    // Reset dirty flags after rendering
}
```

---

## PTY I/O Model

### Data Flow

```
Shell Process ←→ PTY ←→ portable-pty Reader ←→ terminal.vt_write()
                         portable-pty Writer ←→ terminal.on_pty_write() callback
```

### Key Points

1. **PTY is external to libghostty-vt** — you use `portable-pty` (or `forkpty()` directly) to create/manage the PTY
2. **Feed output to terminal** via `ghostty_terminal_vt_write()` / `terminal.vt_write()`
3. **Terminal responses** (query answers) come through the `WRITE_PTY` effect callback — write them back to the PTY
4. **No built-in PTY management** in libghostty-vt — it's a pure VT parser/state machine

### Practical Pattern (from godotty)

```rust
// godotty uses portable-pty for cross-platform PTY
pub fn drain(&mut self, mut on_data: impl FnMut(&[u8])) -> Drained {
    let mut reader = self.reader.lock().unwrap();
    let mut buf = [0u8; DRAIN_BUDGET]; // 4MB budget per frame
    match reader.read(&mut buf) {
        Ok(0) => Drained::Eof,
        Ok(n) => {
            on_data(&buf[..n]);
            Drained::Data
        }
        Err(e) if e.kind() == io::ErrorKind::WouldBlock => Drained::Empty,
        Err(_) => Drained::Eof,
    }
}
```

---

## Input Forwarding

### Keyboard Input

```rust
// 1. Create key encoder (once per terminal)
let key_encoder = key::Encoder::new()?;
let key_event = key::Event::new()?;

// 2. On each key event from your UI
key_event
    .set_action(key::Action::Press)       // Press/Release/Repeat
    .set_key(key::Key::C)                  // W3C key code
    .set_mods(key::Mods::CTRL)            // Modifier bitmask
    .set_consumed_mods(key::Mods::SHIFT)  // Mods that shaped the text
    .set_utf8(Some("c"))                  // UTF-8 text (if any)
    .set_unshifted_codepoint('c');         // Base codepoint

// 3. Sync encoder from terminal state (Kitty flags, cursor mode, etc.)
key_encoder.set_options_from_terminal(&terminal)?;

// 4. Encode to VT sequence
let mut buf = [0u8; 128];
let len = key_encoder.encode_to_vec(&key_event, &mut buf)?;

// 5. Write to PTY
pty_writer.write_all(&buf[..len])?;
```

### Mouse Input

```rust
let mouse_encoder = mouse::Encoder::new()?;
let mouse_event = mouse::Event::new()?;

// Configure encoder size for coordinate mapping
mouse_encoder.set_size(mouse::EncoderSize {
    screen_width: 800,
    screen_height: 600,
    cell_width: 10,
    cell_height: 20,
    padding_top: 4,
    padding_bottom: 4,
    padding_left: 4,
    padding_right: 4,
})?;

// On mouse event
mouse_event
    .set_action(mouse::Action::Press)
    .set_button(mouse::Button::Left)
    .set_mods(key::Mods::empty())
    .set_position(mouse::Position { x: 50.0, y: 40.0 });

// Sync from terminal (tracking mode, format)
mouse_encoder.set_options_from_terminal(&terminal)?;

// Encode
let len = mouse_encoder.encode_to_vec(&mouse_event, &mut buf)?;
pty_writer.write_all(&buf[..len])?;
```

### Focus Events

```rust
let focus_encoder = focus::Encoder::new()?;
let mut focus_buf = [0u8; 32];
let len = focus_encoder.encode(&mut focus_buf, true)?; // true = focused
pty_writer.write_all(&focus_buf[..len])?;
```

---

## Threading Model

### libghostty-vt Threading Rules

**All handle types are `Send` but NOT `Sync`.**

This means:
- A `Terminal` can be moved to another thread
- But only **one thread** can access a `Terminal` at a time
- `RenderState` can be safely multi-threaded **only if** a lock is held during `update()` to ensure exclusive access to the terminal

### Recommended Pattern for Multi-Pane

```
┌─────────────────────────────────────────────────┐
│ Main Thread (UI event loop)                      │
│  ├── Receives keyboard/mouse events             │
│  ├── Dispatches to correct pane                  │
│  └── Triggers render state updates               │
│                                                  │
│ Per-Pane Thread (or async task)                  │
│  ├── Owns Terminal + RenderState + KeyEncoder    │
│  ├── Reads PTY output → vt_write()              │
│  └── Writes encoded input → PTY                 │
└─────────────────────────────────────────────────┘
```

**Option A: Single-threaded event loop (simpler)**
- All panes share one thread
- Poll PTY for each pane in round-robin
- Update render states sequentially
- Good for moderate pane counts (<20)

**Option B: Per-pane threads (higher throughput)**
- Each pane runs its own PTY read thread
- Use `channel` to send VT data to main thread
- Main thread owns all `Terminal` + `RenderState` pairs
- Render state updates happen on main thread (UI thread)

**Option C: Async tasks (Godotty pattern)**
- Each pane spawns an async task for PTY I/O
- Uses `Arc<Mutex<Terminal>>` or message passing
- Render state updates on UI frame callback

### Godotty's Approach (Production Reference)

Godotty uses a **single-threaded model** with frame-rate polling:
1. `process(delta)` called every frame
2. `pty.drain(|chunk| vt.vt_write(chunk))` — reads all available PTY output
3. `render_state.update(&terminal)` — captures snapshot
4. Read dirty state and render changed cells
5. Resize debouncing (0.1s settle time) to avoid spam-redrawing

This is the simplest and most proven pattern.

---

## Configuration

### libghostty-vt Configuration

Minimal configuration in libghostty-vt — most options are set at terminal creation:

```rust
let terminal = Terminal::new(TerminalOptions {
    cols: 80,
    rows: 24,
    max_scrollback: 10_000,
})?;
```

Additional configuration via effects:
- Colors (foreground, background, palette) via `ghostty_terminal_set()`
- Selection via `ghostty_terminal_set()`
- Key encoder options via `ghostty_key_encoder_setopt()`

### Full libghostty Configuration (ghostty.h)

```c
ghostty_config_t config = ghostty_config_new();
ghostty_config_load_file(config, "~/.config/ghostty/config");
ghostty_config_load_default_files(config);
ghostty_config_finalize(config);

// Check for errors
uint32_t count = ghostty_config_diagnostics_count(config);
for (uint32_t i = 0; i < count; i++) {
    ghostty_diagnostic_s diag = ghostty_config_get_diagnostic(config, i);
    fprintf(stderr, "Config error: %s\n", diag.message);
}
```

---

## Host Callbacks

### For libghostty-vt (Effect Callbacks)

The host registers callbacks via `ghostty_terminal_set()`:

```c
// PTY write-back callback (query responses)
void on_write_pty(GhosttyTerminal term, void* userdata, const uint8_t* data, size_t len) {
    // Write data back to PTY master fd
    write(pty_fd, data, len);
}

// Bell callback
void on_bell(GhosttyTerminal term, void* userdata) {
    // Ring bell, flash title bar, etc.
}

// Title changed callback
void on_title_changed(GhosttyTerminal term, void* userdata) {
    // Update window/tab title
}

// Registration
ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_USERDATA, &my_state);
ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_WRITE_PTY, on_write_pty);
ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_BELL, on_bell);
ghostty_terminal_set(terminal, GHOSTTY_TERMINAL_OPT_TITLE_CHANGED, on_title_changed);
```

### For Full libghostty (Runtime Callbacks)

```c
ghostty_runtime_config_s runtime = {
    .userdata = my_app_state,
    .supports_selection_clipboard = true,
    .wakeup_cb = on_wakeup,           // Signal event loop
    .action_cb = on_action,           // Handle terminal actions
    .read_clipboard_cb = on_read_clip, // Read clipboard
    .write_clipboard_cb = on_write_clip, // Write clipboard
    .close_surface_cb = on_close,     // Surface closed
};
```

---

## Rust FFI Integration

### Option 1: Use libghostty-rs (Recommended)

The `libghostty-vt` ecosystem provides safe Rust wrappers:

```toml
# Cargo.toml
[dependencies]
libghostty-vt = "0.2"
```

```rust
use libghostty_vt::{Terminal, TerminalOptions, RenderState};
use libghostty_vt::key::{Encoder as KeyEncoder, Event as KeyEvent, Mods};
use libghostty_vt::mouse::{Encoder as MouseEncoder, Event as MouseEvent};
use libghostty_vt::render::{RowIterator, CellIterator};

// Terminal lifecycle
let mut terminal = Terminal::new(TerminalOptions {
    cols: 80, rows: 24, max_scrollback: 10_000,
})?;

// Effect callbacks
terminal.on_pty_write(|_term, data| { /* write to PTY */ })?;
terminal.on_bell(|_term| { /* ring bell */ })?;
terminal.on_title_changed(|_term| { /* update title */ })?;

// VT data input
terminal.vt_write(b"\x1b[1;32mHello\x1b[0m\r\n");

// Render state
let mut render_state = RenderState::new()?;
render_state.update(&terminal)?;

// Read cells
let mut rows = RowIterator::new()?;
let mut cells = CellIterator::new()?;
let mut row_iter = rows.update(&render_state)?;
while let Some(row) = row_iter.next() {
    let mut cell_iter = cells.update(row)?;
    while let Some(cell) = cell_iter.next() {
        let graphemes = cell.graphemes()?;
        // Render cell...
    }
}
```

### Option 2: Raw FFI (If Wrappers Don't Fit)

```rust
use std::os::raw::{c_char, c_int, c_void};
use std::ptr;

#[repr(C)]
struct GhosttyTerminalOptions {
    cols: u16,
    rows: u16,
    max_scrollback: u32,
}

extern "C" {
    fn ghostty_terminal_new(
        allocator: *const c_void,
        out: *mut *mut c_void,
        opts: GhosttyTerminalOptions,
    ) -> c_int;
    fn ghostty_terminal_free(terminal: *mut c_void);
    fn ghostty_terminal_vt_write(
        terminal: *mut c_void,
        data: *const u8,
        len: usize,
    );
    fn ghostty_render_state_new(
        allocator: *const c_void,
        out: *mut *mut c_void,
    ) -> c_int;
    fn ghostty_render_state_update(
        state: *mut c_void,
        terminal: *mut c_void,
    ) -> c_int;
}

unsafe fn create_terminal(cols: u16, rows: u16) -> Result<*mut c_void, c_int> {
    let mut terminal = ptr::null_mut();
    let opts = GhosttyTerminalOptions {
        cols, rows, max_scrollback: 10_000,
    };
    let result = ghostty_terminal_new(ptr::null(), &mut terminal, opts);
    if result == 0 { Ok(terminal) } else { Err(result) }
}
```

### Option 3: Custom sys crate (If Vendoring)

```rust
// build.rs — link against vendored libghostty-vt
fn main() {
    println!("cargo:rustc-link-lib=ghostty-vt");
    println!("cargo:rustc-link-search=native={}", env!("GHOSTTY_LIB_DIR"));
}
```

---

## Existing Bindings

### Active/Maintained

| Crate | Version | Scope | Status |
|---|---|---|---|
| `libghostty-vt` | 0.2.0 | Safe Rust API for VT engine | ✅ Active, 24k downloads |
| `libghostty-vt-sys` | 0.2.1 | Raw FFI bindings for VT engine | ✅ Active |
| `ratatui-ghostty` | 0.2.0 | ratatui widget rendering libghostty-vt | ✅ Active |

### Archived/Unmaintained

| Crate | Version | Scope | Status |
|---|---|---|---|
| `ghostty-sys` | 0.1.1 | Full libghostty embedding API | ❌ Archived |

### Production Users

| Project | Description |
|---|---|
| **godotty** | Godot Engine terminal — Rust GDExtension using libghostty-vt |
| **moai-studio** | Agent IDE with multi-pane terminal multiplexer |
| **Turborepo** | Migrated from vt100 to libghostty-vt (vendored) |
| **gpui-ghostty** | Zed's GPUI + Ghostty embedded terminal |

---

## Code Examples

### Minimal Terminal (Rust)

```rust
use libghostty_vt::{Terminal, TerminalOptions, RenderState};
use libghostty_vt::render::{RowIterator, CellIterator};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut terminal = Terminal::new(TerminalOptions {
        cols: 80, rows: 24, max_scrollback: 10_000,
    })?;

    terminal.on_pty_write(|_term, data| {
        print!("[PTY] {}", String::from_utf8_lossy(data));
    })?;

    terminal.vt_write(b"Hello, \x1b[1;32mworld\x1b[0m!\r\n");

    let mut render_state = RenderState::new()?;
    render_state.update(&terminal)?;

    let mut rows = RowIterator::new()?;
    let mut cells = CellIterator::new()?;
    let mut row_iter = rows.update(&render_state)?;

    while let Some(row) = row_iter.next() {
        let mut cell_iter = cells.update(row)?;
        while let Some(cell) = cell_iter.next() {
            let graphemes = cell.graphemes()?;
            print!("{graphemes:?}");
        }
        println!();
    }

    Ok(())
}
```

### Key Encoding (Rust)

```rust
use libghostty_vt::key::{self, Encoder, Event, Mods};

fn encode_ctrl_c(encoder: &mut Encoder, event: &mut Event) -> Vec<u8> {
    event
        .set_action(key::Action::Press)
        .set_key(key::Key::C)
        .set_mods(Mods::CTRL)
        .set_utf8(None);

    let mut buf = Vec::with_capacity(64);
    encoder.encode_to_vec(event, &mut buf).unwrap();
    buf
}
```

### Mouse Encoding with Terminal Sync (Rust)

```rust
use libghostty_vt::mouse::{self, Encoder, Event};
use libghostty_vt::Terminal;

fn encode_click(
    encoder: &mut Encoder,
    event: &mut Event,
    terminal: &Terminal,
    x: f32, y: f32,
) -> Vec<u8> {
    event
        .set_action(mouse::Action::Press)
        .set_button(mouse::Button::Left)
        .set_position(mouse::Position { x, y });

    encoder.set_options_from_terminal(terminal).unwrap();
    encoder.set_size(mouse::EncoderSize {
        screen_width: 800, screen_height: 600,
        cell_width: 10, cell_height: 20,
        padding_top: 4, padding_bottom: 4,
        padding_left: 4, padding_right: 4,
    });

    let mut buf = Vec::with_capacity(64);
    encoder.encode_to_vec(event, &mut buf).unwrap();
    buf
}
```

---

## Integration Strategy for GN Harness

### Recommended Approach: libghostty-vt + ratatui

```
┌─────────────────────────────────────────────────┐
│ GN Harness                                      │
│                                                  │
│  ┌──────────────┐    ┌──────────────────────┐   │
│  │ ratatui      │    │ libghostty-vt        │   │
│  │ (rendering)  │←───│ (terminal emulation) │   │
│  │              │    │                      │   │
│  │ Buffer →     │    │ Terminal per pane    │   │
│  │ Terminal     │    │ RenderState          │   │
│  │ Widget       │    │ KeyEncoder           │   │
│  └──────────────┘    │ MouseEncoder         │   │
│                      └──────────┬───────────┘   │
│                                 │                │
│                      ┌──────────┴───────────┐   │
│                      │ portable-pty         │   │
│                      │ (PTY per pane)       │   │
│                      └──────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Step-by-Step Integration

1. **Add dependencies:**
   ```toml
   [dependencies]
   libghostty-vt = "0.2"
   portable-pty = "0.8"
   ratatui = "0.28"
   ```

2. **Create Pane struct:**
   ```rust
   struct Pane {
       terminal: Terminal,
       render_state: RenderState,
       key_encoder: KeyEncoder,
       mouse_encoder: MouseEncoder,
       pty_reader: Box<dyn Read>,
       pty_writer: Box<dyn Write>,
       child: Box<dyn Child>,
   }
   ```

3. **Implement Pane methods:**
   - `new(cols, rows, shell, cwd)` — spawn PTY, create terminal
   - `write_input(data)` — encode and write to PTY
   - `drain_output()` — read PTY → vt_write
   - `render(buffer)` — update render state, write to ratatui buffer
   - `resize(cols, rows)` — resize terminal + PTY
   - `close()` — kill child, cleanup

4. **Main event loop:**
   ```rust
   loop {
       // 1. Poll terminal events (keyboard, mouse)
       // 2. Dispatch to focused pane
       // 3. Drain all pane PTY outputs
       // 4. Update render states
       // 5. Render to ratatui buffer
       // 6. Draw to screen
   }
   ```

### Key Design Decisions

| Decision | Recommendation | Rationale |
|---|---|---|
| **Single vs multi-threaded** | Single-threaded | Simpler, sufficient for <20 panes, proven in godotty |
| **PTY library** | `portable-pty` | Cross-platform, battle-tested, used by godotty |
| **Rendering** | ratatui | Already in ecosystem, `ratatui-ghostty` exists |
| **Scrollback** | 10,000 lines default | Balances memory and usability |
| **Resize handling** | Debounce 100ms | Avoids spam-redrawing during resize drag |

---

## Risks and Open Questions

### High Risk

1. **libghostty-vt API instability** — The library explicitly warns: "This library is currently in development and the API is not yet stable. Breaking changes are expected in future versions." Pin to exact version, test upgrades carefully.

2. **Zig build dependency** — Requires Zig 0.15.2 on PATH. This is a non-trivial build dependency for CI/CD. The `libghostty-vt-sys` build script auto-fetches source, but Zig must be installed.

3. **No `Sync` on handles** — All libghostty-vt handles are `Send` but not `Sync`. Multi-threaded pane management requires careful ownership design.

### Medium Risk

4. **Kitty graphics protocol** — libghostty-vt supports it, but rendering integration with ratatui is unclear. The `kitty-graphics` feature in `libghostty-vt-sys` enables it at the C level.

5. **Unicode/emoji width** — libghostty-vt handles Unicode codepoint properties, but double-width characters and emoji may need additional handling in the ratatui rendering layer.

6. **Selection handling** — libghostty-vt provides selection gesture tracking, but integrating with ratatui's selection model requires custom work.

### Low Risk

7. **Font handling** — libghostty-vt doesn't handle fonts; that's the renderer's job. ratatui handles this via its font stack.

8. **Clipboard** — Handled at the application level, not by libghostty-vt. The full `ghostty.h` has clipboard callbacks, but the VT-only library doesn't.

### Open Questions

- **Performance at scale:** How does libghostty-vt perform with 50+ concurrent panes? The VT parser is fast, but render state updates for many panes could be a bottleneck.
- **Termux compatibility:** Does libghostty-vt handle Termux-specific escape sequences?
- **Custom escape sequences:** Can we add custom OSC handlers beyond the built-in set?
- **Memory usage per pane:** What's the baseline memory footprint of a Terminal + RenderState pair?

---

## Sources

1. **ghostty.h** — https://github.com/ghostty-org/ghostty/blob/main/include/ghostty.h (1216 lines)
2. **libghostty-vt Doxygen** — https://libghostty.tip.ghostty.org/index.html
3. **libghostty-rs** — https://github.com/Uzaaft/libghostty-rs (workspace with -sys and -vt crates)
4. **godotty** — https://github.com/ingur/godotty (Rust terminal for Godot)
5. **moai-studio** — https://github.com/modu-ai/moai-studio (multi-pane terminal multiplexer)
6. **ratatui-ghostty** — https://crates.io/crates/ratatui-ghostty
7. **awesome-libghostty** — https://github.com/Uzaaft/awesome-libghostty
8. **ghostling** — https://github.com/ghostty-org/ghostling (reference C embedding example)
