//! Theme — Matugen palette watcher contract (S187 widget spec §1.3).
//!
//! Mirrors `MatugenColors.qml` exactly: 22 named colors read from
//! `/tmp/qs_colors.json` (written by `matugen-sync.sh`), Catppuccin Mocha
//! fallbacks, plus the NightForge `performanceMode` gate.
//!
//! This is the shared palette every widget scene reads. The frame loop
//! re-reads `Theme` each frame, so a theme change repaints on the next
//! frame with no binding layer.

use std::path::Path;

use serde::Deserialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rgb {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Rgb {
    /// Parse `#rrggbb` (leading `#` optional). Const-friendly parser.
    pub const fn from_hex(hex: &str) -> Self {
        let bytes = hex.as_bytes();
        let mut v: u32 = 0;
        let mut digits = 0;
        let mut i = 0;
        while i < bytes.len() && digits < 6 {
            let b = bytes[i];
            let d = match b {
                b'0'..=b'9' => b - b'0',
                b'a'..=b'f' => b - b'a' + 10,
                b'A'..=b'F' => b - b'A' + 10,
                _ => {
                    i += 1;
                    continue;
                }
            };
            v = (v << 4) | d as u32;
            digits += 1;
            i += 1;
        }
        Rgb {
            r: ((v >> 16) & 0xff) as u8,
            g: ((v >> 8) & 0xff) as u8,
            b: (v & 0xff) as u8,
        }
    }

    /// Premultiplied RGBA float for wgpu clears/uniforms.
    pub fn premul_f32(self, alpha: f32) -> [f32; 4] {
        let a = alpha.clamp(0.0, 1.0);
        [
            self.r as f32 / 255.0 * a,
            self.g as f32 / 255.0 * a,
            self.b as f32 / 255.0 * a,
            a,
        ]
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Theme {
    pub base: Rgb,
    pub mantle: Rgb,
    pub crust: Rgb,
    pub text: Rgb,
    pub subtext0: Rgb,
    pub subtext1: Rgb,
    pub surface0: Rgb,
    pub surface1: Rgb,
    pub surface2: Rgb,
    pub overlay0: Rgb,
    pub overlay1: Rgb,
    pub overlay2: Rgb,
    pub blue: Rgb,
    pub sapphire: Rgb,
    pub peach: Rgb,
    pub green: Rgb,
    pub red: Rgb,
    pub mauve: Rgb,
    pub pink: Rgb,
    pub yellow: Rgb,
    pub maroon: Rgb,
    pub teal: Rgb,
    /// NightForge perf gate: low → no blur/animations.
    pub animation_enabled: bool,
}

/// Catppuccin Mocha — identical to the QML fallbacks.
pub const MOCHA_FALLBACK: Theme = Theme {
    base: Rgb::from_hex("#1e1e2e"),
    mantle: Rgb::from_hex("#181825"),
    crust: Rgb::from_hex("#11111b"),
    text: Rgb::from_hex("#cdd6f4"),
    subtext0: Rgb::from_hex("#a6adc8"),
    subtext1: Rgb::from_hex("#bac2de"),
    surface0: Rgb::from_hex("#313244"),
    surface1: Rgb::from_hex("#45475a"),
    surface2: Rgb::from_hex("#585b70"),
    overlay0: Rgb::from_hex("#6c7086"),
    overlay1: Rgb::from_hex("#7f849c"),
    overlay2: Rgb::from_hex("#9399b2"),
    blue: Rgb::from_hex("#89b4fa"),
    sapphire: Rgb::from_hex("#74c7ec"),
    peach: Rgb::from_hex("#fab387"),
    green: Rgb::from_hex("#a6e3a1"),
    red: Rgb::from_hex("#f38ba8"),
    mauve: Rgb::from_hex("#cba6f7"),
    pink: Rgb::from_hex("#f5c2e7"),
    yellow: Rgb::from_hex("#f9e2af"),
    maroon: Rgb::from_hex("#eba0ac"),
    teal: Rgb::from_hex("#94e2d5"),
    animation_enabled: true,
};

/// JSON shape written by `matugen-sync.sh` → `/tmp/qs_colors.json`.
#[derive(Deserialize)]
struct ColorsFile {
    #[serde(default)]
    base: Option<String>,
    #[serde(default)]
    mantle: Option<String>,
    #[serde(default)]
    crust: Option<String>,
    #[serde(default)]
    text: Option<String>,
    #[serde(default)]
    subtext0: Option<String>,
    #[serde(default)]
    subtext1: Option<String>,
    #[serde(default)]
    surface0: Option<String>,
    #[serde(default)]
    surface1: Option<String>,
    #[serde(default)]
    surface2: Option<String>,
    #[serde(default)]
    overlay0: Option<String>,
    #[serde(default)]
    overlay1: Option<String>,
    #[serde(default)]
    overlay2: Option<String>,
    #[serde(default)]
    blue: Option<String>,
    #[serde(default)]
    sapphire: Option<String>,
    #[serde(default)]
    peach: Option<String>,
    #[serde(default)]
    green: Option<String>,
    #[serde(default)]
    red: Option<String>,
    #[serde(default)]
    mauve: Option<String>,
    #[serde(default)]
    pink: Option<String>,
    #[serde(default)]
    yellow: Option<String>,
    #[serde(default)]
    maroon: Option<String>,
    #[serde(default)]
    teal: Option<String>,
}

/// Read + parse `/tmp/qs_colors.json`; on any failure return Mocha fallback.
///
/// The QML contract tolerates a missing/empty file (returns fallbacks), so
/// this mirrors that: never panics, never blocks the shell.
pub fn load_from_path(path: &Path) -> Theme {
    let raw = match std::fs::read_to_string(path) {
        Ok(s) => s,
        Err(_) => return MOCHA_FALLBACK,
    };
    let f: ColorsFile = match serde_json::from_str(&raw) {
        Ok(f) => f,
        Err(_) => return MOCHA_FALLBACK,
    };
    let mut t = MOCHA_FALLBACK;
    macro_rules! apply {
        ($($field:ident),*) => { $( if let Some(v) = f.$field { t.$field = Rgb::from_hex(&v); } )* };
    }
    apply!(
        base, mantle, crust, text, subtext0, subtext1, surface0, surface1, surface2,
        overlay0, overlay1, overlay2, blue, sapphire, peach, green, red, mauve, pink,
        yellow, maroon, teal
    );
    t
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_parses() {
        assert_eq!(Rgb::from_hex("#cba6f7"), Rgb { r: 0xcb, g: 0xa6, b: 0xf7 });
        assert_eq!(Rgb::from_hex("1e1e2e"), Rgb { r: 0x1e, g: 0x1e, b: 0x2e });
    }

    #[test]
    fn fallback_on_missing_file() {
        assert_eq!(load_from_path(Path::new("/nonexistent/qs_colors.json")), MOCHA_FALLBACK);
    }

    #[test]
    fn parses_real_shape() {
        let dir = std::env::temp_dir().join("nf-theme-test.json");
        std::fs::write(&dir, r##"{"base":"#000000","mauve":"#ff00ff","blue":"#123456"}"##).unwrap();
        let t = load_from_path(&dir);
        std::fs::remove_file(&dir).ok();
        assert_eq!(t.base, Rgb { r: 0, g: 0, b: 0 });
        assert_eq!(t.mauve, Rgb { r: 0xff, g: 0, b: 0xff });
        assert_eq!(t.blue, Rgb { r: 0x12, g: 0x34, b: 0x56 });
        // untouched fields keep fallbacks
        assert_eq!(t.crust, MOCHA_FALLBACK.crust);
    }
}
