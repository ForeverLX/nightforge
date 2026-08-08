//! Text rasterization via cosmic-text (S187 plan §4.1: glyph atlas path,
//! spike uses per-string CPU raster → texture upload).
//!
//! `rasterize` shapes + draws a string into a premultiplied RGBA pixmap.
//! The spike uploads that pixmap as a wgpu texture and draws it as a quad;
//! the eventual shell keeps a persistent glyph atlas instead.

use cosmic_text::{Attrs, Buffer, Color, FontSystem, Metrics, Shaping, SwashCache};

pub struct RasterText {
    pub width: u32,
    pub height: u32,
    /// Premultiplied RGBA, row-major, top-left origin.
    pub pixels: Vec<u8>,
}

/// Rasterize `text` at `size_px` (logical = physical px at scale 1.0).
/// `color` is straight RGBA; output pixels are premultiplied.
pub fn rasterize(
    font_system: &mut FontSystem,
    text: &str,
    size_px: f32,
    color: [u8; 4],
) -> RasterText {
    let mut buffer = Buffer::new(font_system, Metrics::new(size_px, size_px * 1.4));
    // Wide canvas, auto height: text lays out on one line.
    buffer.set_size(Some(8192.0), None);
    buffer.set_text(text, &Attrs::new(), Shaping::Advanced, None);
    buffer.shape_until_scroll(font_system, false);

    // Laid-out extents (cosmic-text 0.19 has no `dimensions()` on Buffer).
    let (mut w, mut h) = (0.0f32, 0.0f32);
    for run in buffer.layout_runs() {
        w = w.max(run.line_w);
        h = (run.line_y + run.line_height).max(h);
    }
    let width = (w.ceil() as u32).max(1) + 2;
    let height = (h.ceil() as u32).max(1) + 2;
    let mut pixels = vec![0u8; width as usize * height as usize * 4];

    let mut cache = SwashCache::new();
    let ct_color = Color::rgba(color[0], color[1], color[2], color[3]);
    buffer.draw(font_system, &mut cache, ct_color, |x, y, w, h, c| {
        let a = c.a() as u32;
        // Premultiply straight RGBA so the texture blends correctly on a
        // premultiplied-alpha surface.
        let pr = (c.r() as u32 * a / 255) as u8;
        let pg = (c.g() as u32 * a / 255) as u8;
        let pb = (c.b() as u32 * a / 255) as u8;
        for dy in 0..h {
            for dx in 0..w {
                let px = x + dx as i32;
                let py = y + dy as i32;
                if px >= 0 && py >= 0 && px < width as i32 && py < height as i32 {
                    let i = (py as usize * width as usize + px as usize) * 4;
                    pixels[i] = pr;
                    pixels[i + 1] = pg;
                    pixels[i + 2] = pb;
                    pixels[i + 3] = a as u8;
                }
            }
        }
    });

    RasterText { width, height, pixels }
}
