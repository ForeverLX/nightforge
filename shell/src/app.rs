//! S187 Phase 0 spike app: sctk layer-surface state + per-frame draw.
//!
//! One top-anchored layer surface with exclusive zone 48, rendering:
//!   - rounded-rect background with vertical gradient
//!   - cosmic-text rasterized strings (title, subtitle, per-frame clock)
//!   - one animated quad (position + color oscillate with time)
//!
//! The spike is the §4.1 gate: if this renders and behaves (exclusive
//! zone, focus) on Niri, the wgpu shell path proceeds.

use std::num::NonZeroU32;
use std::time::Instant;

use cosmic_text::FontSystem;
use log::info;
use smithay_client_toolkit::compositor::{CompositorHandler, CompositorState, FrameCallbackData};
use smithay_client_toolkit::delegate_registry;
use smithay_client_toolkit::output::{OutputHandler, OutputState};
use smithay_client_toolkit::registry::{ProvidesRegistryState, RegistryState};
use smithay_client_toolkit::registry_handlers;
use smithay_client_toolkit::seat::keyboard::{KeyEvent, KeyboardHandler, Keysym};
use smithay_client_toolkit::seat::pointer::{PointerEvent, PointerEventKind, PointerHandler};
use smithay_client_toolkit::seat::{Capability, SeatHandler, SeatState};
use smithay_client_toolkit::shell::wlr_layer::{
    Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
    LayerSurfaceConfigure,
};
use smithay_client_toolkit::shell::WaylandSurface;
use wayland_client::protocol::{wl_keyboard, wl_output, wl_pointer, wl_seat, wl_surface};
use wayland_client::{Connection, QueueHandle};

use crate::dirs::QsDirs;
use crate::render::{Frame, Renderer, ShapeUniform, TexUniform};
use crate::text;
use crate::theme::{self, Rgb, Theme, MOCHA_FALLBACK};
use bytemuck::Zeroable;

/// Exclusive zone for the bar (px). Niri reserves this strip on the output.
const EXCLUSIVE_ZONE: i32 = 48;
const BAR_HEIGHT: u32 = 48;

pub struct App {
    registry_state: RegistryState,
    seat_state: SeatState,
    output_state: OutputState,

    pub(crate) exit: bool,
    first_configure: bool,
    width: u32,
    height: u32,
    layer: LayerSurface,
    keyboard: Option<wl_keyboard::WlKeyboard>,
    pointer: Option<wl_pointer::WlPointer>,
    keyboard_focus: bool,

    pub(crate) renderer: Option<Renderer>,
    theme: Theme,
    font_system: FontSystem,
    start: Instant,
    frames: u64,
    // Static text textures (rasterized once).
    title_tex: Option<(wgpu::Texture, wgpu::BindGroup)>,
    subtitle_tex: Option<(wgpu::Texture, wgpu::BindGroup)>,
    hint_tex: Option<(wgpu::Texture, wgpu::BindGroup)>,
    // Per-second clock texture (re-rasterized when the string changes).
    clock_tex: Option<(wgpu::Texture, wgpu::BindGroup)>,
    clock_str: String,
}

impl App {
    pub fn new(
        conn: &Connection,
        qh: &QueueHandle<Self>,
        globals: &wayland_client::globals::GlobalList,
        compositor: CompositorState,
        layer_shell: LayerShell,
    ) -> Self {
        let surface = compositor.create_surface(qh);
        let layer = layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Top,
            Some("wgpu-spike"),
            None,
        );
        layer.set_anchor(Anchor::TOP | Anchor::LEFT | Anchor::RIGHT);
        layer.set_size(0, BAR_HEIGHT);
        layer.set_exclusive_zone(EXCLUSIVE_ZONE);
        layer.set_keyboard_interactivity(KeyboardInteractivity::OnDemand);
        layer.commit();

        let renderer = Renderer::new(conn, &layer.wl_surface().clone());

        // Widget extraction groundwork (§1.3): load the live Matugen palette;
        // falls back to Catppuccin Mocha when /tmp/qs_colors.json is absent.
        let theme = theme::load_from_path(std::path::Path::new("/tmp/qs_colors.json"));
        let dirs = QsDirs::for_widget("shell");
        info!(
            "theme: base={:02X}{:02X}{:02X} (fallback={})",
            theme.base.r,
            theme.base.g,
            theme.base.b,
            theme == MOCHA_FALLBACK
        );
        info!("dirs: cache={} run={}", dirs.cache.display(), dirs.run.display());

        App {
            registry_state: RegistryState::new(globals),
            seat_state: SeatState::new(globals, qh),
            output_state: OutputState::new(globals, qh),

            exit: false,
            first_configure: true,
            width: BAR_HEIGHT,
            height: BAR_HEIGHT,
            layer,
            keyboard: None,
            pointer: None,
            keyboard_focus: false,

            renderer: Some(renderer),
            theme,
            font_system: FontSystem::new(),
            start: Instant::now(),
            frames: 0,
            title_tex: None,
            subtitle_tex: None,
            hint_tex: None,
            clock_tex: None,
            clock_str: String::new(),
        }
    }

    fn ensure_static_text(&mut self) {
        if self.title_tex.is_some() {
            return;
        }
        let renderer = self.renderer.as_ref().unwrap();
        let title = text::rasterize(&mut self.font_system, "wgpu spike — S187 Phase 0", 15.0, [0xcd, 0xd6, 0xf4, 0xff]);
        self.title_tex = Some(renderer.upload_texture(&title));
        let subtitle = text::rasterize(
            &mut self.font_system,
            "layer-shell · exclusive zone 48 · Niri 26.04",
            11.0,
            [0xa6, 0xad, 0xc8, 0xff],
        );
        self.subtitle_tex = Some(renderer.upload_texture(&subtitle));
        let hint = text::rasterize(&mut self.font_system, "esc = exit", 11.0, [0x93, 0x99, 0xb2, 0xff]);
        self.hint_tex = Some(renderer.upload_texture(&hint));
    }

    fn ensure_clock_text(&mut self) {
        let secs = self.start.elapsed().as_secs();
        let s = format!("t = {secs:>3}s · frame {}", self.frames);
        if s == self.clock_str {
            return;
        }
        self.clock_str = s;
        let raster = text::rasterize(&mut self.font_system, &self.clock_str, 11.0, [0xa6, 0xe3, 0xa1, 0xff]);
        let renderer = self.renderer.as_ref().unwrap();
        self.clock_tex = Some(renderer.upload_texture(&raster));
    }

    fn draw(&mut self, qh: &QueueHandle<Self>) {
        self.ensure_static_text();
        self.ensure_clock_text();
        self.frames += 1;

        let renderer = self.renderer.as_mut().unwrap();
        let (w, h) = renderer.size;
        let now = self.start.elapsed().as_secs_f32();
        let theme = self.theme;

        let frame = match renderer.begin_frame() {
            Frame::Ready { surface_texture, view, encoder } => (surface_texture, view, encoder),
            Frame::Skip => {
                self.request_next_frame(qh);
                return;
            }
        };
        let (surface_texture, view, mut encoder) = frame;

        // 1. Clear — translucent mantle, premultiplied.
        renderer.clear(&mut encoder, &view, theme.mantle.premul_f32(0.96));

        let size = [w as f32, h as f32];

        // 2. Background: full-bar rounded rect, vertical gradient mantle → base.
        renderer.draw_shape(
            &mut encoder,
            &view,
            ShapeUniform {
                rect: [0.0, 0.0, w as f32, h as f32],
                radius: 14.0,
                time: now,
                color_a: theme.mantle.premul_f32(0.96),
                color_b: theme.base.premul_f32(0.96),
                size,
                ..ShapeUniform::zeroed()
            },
        );

        // 3. Animated quad: slides horizontally, color pulses mauve ⇄ green.
        let travel = (w as f32 - 24.0 - 44.0).max(1.0);
        let x = 24.0 + ((now * 0.9).sin() + 1.0) * 0.5 * travel;
        let pulse = (now * 1.3).sin() * 0.5 + 0.5;
        let c = lerp_rgb(theme.mauve, theme.green, pulse);
        renderer.draw_shape(
            &mut encoder,
            &view,
            ShapeUniform {
                rect: [x, 10.0, 44.0, 28.0],
                radius: 8.0,
                time: now,
                color_a: c.premul_f32(0.9),
                color_b: c.premul_f32(0.9),
                size,
                ..ShapeUniform::zeroed()
            },
        );

        // 4. Text quads.
        if let Some((_, bg)) = &self.title_tex {
            renderer.draw_texture(
                &mut encoder,
                &view,
                bg,
                TexUniform { rect: [20.0, 7.0, 250.0, 20.0], size, _pad: [0.0; 2] },
            );
        }
        if let Some((_, bg)) = &self.subtitle_tex {
            renderer.draw_texture(
                &mut encoder,
                &view,
                bg,
                TexUniform { rect: [20.0, 28.0, 260.0, 16.0], size, _pad: [0.0; 2] },
            );
        }
        if let Some((_, bg)) = &self.hint_tex {
            renderer.draw_texture(
                &mut encoder,
                &view,
                bg,
                TexUniform { rect: [w as f32 - 90.0, 28.0, 70.0, 16.0], size, _pad: [0.0; 2] },
            );
        }
        if let Some((_, bg)) = &self.clock_tex {
            renderer.draw_texture(
                &mut encoder,
                &view,
                bg,
                TexUniform { rect: [w as f32 - 170.0, 7.0, 150.0, 16.0], size, _pad: [0.0; 2] },
            );
        }

        renderer.present(surface_texture, encoder);
        self.request_next_frame(qh);
    }

    fn request_next_frame(&self, qh: &QueueHandle<Self>) {
        self.layer
            .wl_surface()
            .frame(qh, FrameCallbackData(self.layer.wl_surface().clone()));
    }
}

fn lerp_rgb(a: Rgb, b: Rgb, t: f32) -> Rgb {
    let t = t.clamp(0.0, 1.0);
    Rgb {
        r: (a.r as f32 + (b.r as f32 - a.r as f32) * t).round() as u8,
        g: (a.g as f32 + (b.g as f32 - a.g as f32) * t).round() as u8,
        b: (a.b as f32 + (b.b as f32 - a.b as f32) * t).round() as u8,
    }
}

impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_factor: i32,
    ) {
    }

    fn transform_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_transform: wl_output::Transform,
    ) {
    }

    fn frame(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _time: u32,
    ) {
        self.draw(qh);
    }

    fn surface_enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}

impl LayerShellHandler for App {
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, _layer: &LayerSurface) {
        info!("layer surface closed by compositor");
        self.exit = true;
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        _layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        self.width = NonZeroU32::new(configure.new_size.0).map_or(BAR_HEIGHT, NonZeroU32::get);
        self.height = NonZeroU32::new(configure.new_size.1).map_or(BAR_HEIGHT, NonZeroU32::get);
        info!("configure: {}x{}", self.width, self.height);

        if let Some(renderer) = self.renderer.as_mut() {
            renderer.resize(self.width, self.height);
        }

        if self.first_configure {
            self.first_configure = false;
            self.draw(qh);
        }
    }
}

impl SeatHandler for App {
    fn seat_state(&mut self) -> &mut SeatState {
        &mut self.seat_state
    }
    fn new_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}

    fn new_capability(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        seat: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Keyboard && self.keyboard.is_none() {
            let keyboard =
                self.seat_state.get_keyboard(qh, &seat, None).expect("failed to create keyboard");
            self.keyboard = Some(keyboard);
        }
        if capability == Capability::Pointer && self.pointer.is_none() {
            let pointer = self.seat_state.get_pointer(qh, &seat).expect("failed to create pointer");
            self.pointer = Some(pointer);
        }
    }

    fn remove_capability(
        &mut self,
        _conn: &Connection,
        _: &QueueHandle<Self>,
        _: wl_seat::WlSeat,
        capability: Capability,
    ) {
        if capability == Capability::Keyboard && self.keyboard.is_some() {
            self.keyboard.take().unwrap().release();
        }
        if capability == Capability::Pointer && self.pointer.is_some() {
            self.pointer.take().unwrap().release();
        }
    }

    fn remove_seat(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_seat::WlSeat) {}
}

impl KeyboardHandler for App {
    fn enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        surface: &wl_surface::WlSurface,
        _: u32,
        _: &[u32],
        _: &[Keysym],
    ) {
        if self.layer.wl_surface() == surface {
            info!("keyboard focus entered layer surface");
            self.keyboard_focus = true;
        }
    }

    fn leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        surface: &wl_surface::WlSurface,
        _: u32,
    ) {
        if self.layer.wl_surface() == surface {
            info!("keyboard focus left layer surface");
            self.keyboard_focus = false;
        }
    }

    fn press_key(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        if event.keysym == Keysym::Escape {
            info!("esc pressed — exiting");
            self.exit = true;
        }
    }

    fn repeat_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        let _ = event;
    }

    fn release_key(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        event: KeyEvent,
    ) {
        let _ = event;
    }

    fn update_modifiers(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_keyboard::WlKeyboard,
        _: u32,
        _: smithay_client_toolkit::seat::keyboard::Modifiers,
        _: smithay_client_toolkit::seat::keyboard::RawModifiers,
        _: u32,
    ) {
    }
}

impl PointerHandler for App {
    fn pointer_frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _pointer: &wl_pointer::WlPointer,
        events: &[PointerEvent],
    ) {
        for event in events {
            if &event.surface != self.layer.wl_surface() {
                continue;
            }
            match event.kind {
                PointerEventKind::Enter { .. } => info!("pointer entered @{:?}", event.position),
                PointerEventKind::Leave { .. } => info!("pointer left"),
                PointerEventKind::Motion { .. } => {}
                PointerEventKind::Press { .. } => {}
                PointerEventKind::Release { .. } => {}
                PointerEventKind::Axis { .. } => {}
            }
        }
    }
}

delegate_registry!(App);

impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }
    registry_handlers![OutputState, SeatState];
}

smithay_client_toolkit::delegate_dispatch2!(App);
