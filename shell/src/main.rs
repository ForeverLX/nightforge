//! S187 Phase 0 spike — wgpu layer-shell proof on Niri.
//!
//! Gate (rework plan §4.1): one sctk layer-surface rendering text +
//! rounded rect + gradient + one animated quad, with exclusive-zone and
//! focus behavior verified. Green → the custom wgpu shell path proceeds;
//! red → fall back to the hybrid (Slint panels) option.
//!
//! Run: `cargo run` (inside `shell/`) on the Niri session. Esc exits.

mod app;
mod dirs;
mod render;
mod text;
mod theme;

use std::env;

use log::info;
use smithay_client_toolkit::compositor::CompositorState;
use smithay_client_toolkit::shell::wlr_layer::LayerShell;
use wayland_client::globals::registry_queue_init;
use wayland_client::Connection;

use app::App;

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_millis()
        .init();

    let conn = match Connection::connect_to_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("failed to connect to Wayland: {e}");
            eprintln!("hint: run inside the Niri session (WAYLAND_DISPLAY set)");
            std::process::exit(1);
        }
    };
    let (globals, mut event_queue) = registry_queue_init(&conn).expect("registry init failed");
    let qh = event_queue.handle();

    let compositor = CompositorState::bind(&globals, &qh).expect("wl_compositor not available");
    let layer_shell = LayerShell::bind(&globals, &qh).expect("wlr-layer-shell not available");

    let mut app = App::new(&conn, &qh, &globals, compositor, layer_shell);
    info!("spike started — wayland-1, layer surface committed");

    loop {
        event_queue.blocking_dispatch(&mut app).unwrap();
        if app.exit {
            info!("exiting spike");
            break;
        }
    }

    // Drop the wgpu surface before the wl_surface goes away.
    if let Some(renderer) = app.renderer.take() {
        drop(renderer);
    }
    let _ = env::var("WAYLAND_DISPLAY");
}
