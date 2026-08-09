//! Music — MPD state parser (S187 widget spec §priority 1: Music core).
//!
//! Ports the mpc-parsing logic of `MpdClient.qml` (`parseOutput`/`parseTime`)
//! and the JSON field contract of `music_info.sh` into a typed, pure, fully
//! unit-tested Rust core. This is the data layer the wgpu shell's MusicWidget
//! scene consumes; it holds no GUI state and never touches Wayland.
//!
//! ## Contract (matches the QML exactly)
//!
//! Query commands (drop-in, unchanged from the live shell):
//! ```text
//! mpc -f 'ARTIST=[%artist%] TITLE=[%title%] ALBUM=[%album%] TIME=[%time%]' current
//! mpc status
//! ```
//!
//! - `current` emits one line `ARTIST=[…] TITLE=[…] ALBUM=[…] TIME=[…]`, or
//!   nothing when the queue is stopped/idle.
//! - `status` block carries `[playing]` / `[paused]` and a `MM:SS/MM:SS`
//!   elapsed/total on the current track's line.
//!
//! `format_time` mirrors the QML `formatTime(seconds)` helper verbatim.

use std::process::Command;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct MusicState {
    pub playing: bool,
    pub track: String,
    pub artist: String,
    pub album: String,
    /// Seconds elapsed in the current track.
    pub elapsed: u32,
    /// Total seconds of the current track (`0` when unknown).
    pub total: u32,
}

/// Parse the `mpc -f … current` metadata line into `(artist, track, album)`.
///
/// The QML regexes are `ARTIST=\[([^\]]*)\]`, `TITLE=\[([^\]]*)\]`,
/// `ALBUM=\[([^\]]*)\]`. We scan for each bracketed field independently so a
/// missing field (empty in the format string) still yields empty — matching
/// QML's `match ? match[1] : ""`. Brackets inside a value are not escaped by
/// mpc, so a value cannot legitimately contain `]`; first-closing-bracket
/// semantics are correct.
///
/// Returns `(artist, track, album)`.
pub fn parse_current_line(line: &str) -> (String, String, String) {
    let field = |key: &str| -> String {
        let pat = key.to_string() + "=[";
        match line.find(&pat) {
            Some(start) => {
                let rest = &line[start + pat.len()..];
                match rest.find(']') {
                    Some(end) => rest[..end].to_string(),
                    None => String::new(),
                }
            }
            None => String::new(),
        }
    };
    let artist = field("ARTIST");
    let track = field("TITLE");
    let album = field("ALBUM");
    (artist, track, album)
}

/// Parse the `mpc status` block into `(playing, elapsed, total)`.
///
/// Mirrors QML: `playing` is true iff any line contains `[playing]`; time is
/// the first `MM:SS/MM:SS` match. `elapsed`/`total` default to 0.
pub fn parse_status_block(block: &str) -> (bool, u32, u32) {
    let mut playing = false;
    let mut elapsed = 0u32;
    let mut total = 0u32;

    for line in block.lines() {
        let line = line.trim();
        if line.contains("[playing]") {
            playing = true;
        }
        if let Some((e, t)) = parse_time_pair(line) {
            elapsed = e;
            total = t;
        }
    }
    (playing, elapsed, total)
}

/// Combine both mpc invocations into a full `MusicState`.
///
/// This is the QML `parseOutput` analogue: metadata from `current`, state/time
/// from `status`. The `TIME=[…]` field in the current line is parsed but not
/// surfaced (the QML reads elapsed/total from the status block instead).
pub fn parse_mpc_output(current: &str, status: &str) -> MusicState {
    let (artist, track, album) = parse_current_line(current);
    let (playing, elapsed, total) = parse_status_block(status);
    MusicState { playing, track, artist, album, elapsed, total }
}

/// Format seconds as `M:SS` — verbatim port of the QML `formatTime`.
pub fn format_time(secs: u32) -> String {
    let m = secs / 60;
    let s = secs % 60;
    format!("{m}:{s:02}")
}

/// Parse the first `MM:SS/MM:SS` elapsed/total pair in a line.
///
/// Mirrors the QML regex `(\d+:\d+)\/(\d+:\d+)`. We scan for a `/` whose
/// neighbours are both `digits(:digits)` tokens, so the `#1/1` position
/// marker (no colons) is skipped.
fn parse_time_pair(line: &str) -> Option<(u32, u32)> {
    let lt = |t: &str| -> Option<u32> {
        let mut total = 0u32;
        for part in t.split(':') {
            total = total.checked_mul(60)? + part.parse::<u32>().ok()?;
        }
        Some(total)
    };
    let is_time_token = |t: &str| -> bool {
        let mut parts = t.split(':');
        let first = match parts.next() {
            Some(f) => f,
            None => return false,
        };
        if first.is_empty() || !first.chars().all(|c| c.is_ascii_digit()) {
            return false;
        }
        // Require at least one `:` (QML regex is `\d+:\d+`) so positional
        // markers like `#1/1` are not mistaken for track time.
        let mut rest = parts;
        match rest.next() {
            None => return false,
            Some(p) => {
                if !p.is_empty() && !p.chars().all(|c| c.is_ascii_digit()) {
                    return false;
                }
            }
        }
        rest.all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()))
    };

    let bytes = line.as_bytes();
    for (i, &b) in bytes.iter().enumerate() {
        if b != b'/' {
            continue;
        }
        // Walk left to the start of the left token, right to the end of the right.
        let mut lstart = i;
        while lstart > 0 && (line.as_bytes()[lstart - 1].is_ascii_digit() || line.as_bytes()[lstart - 1] == b':') {
            lstart -= 1;
        }
        let mut rend = i + 1;
        while rend < bytes.len() && (bytes[rend].is_ascii_digit() || bytes[rend] == b':') {
            rend += 1;
        }
        let (l, r) = (&line[lstart..i], &line[i + 1..rend]);
        if is_time_token(l) && is_time_token(r) {
            return Some((lt(l)?, lt(r)?));
        }
    }
    None
}

/// Run mpc and return its stdout. `args` excludes the leading `mpc`.
pub fn run_mpc(args: &[&str]) -> Result<String, MusicError> {
    let out = Command::new("mpc").args(args).output()?;
    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
        return Err(MusicError::Mpc { stderr });
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Fetch live MPD state from `mpc` (two subprocess calls). Never panics;
/// on any failure returns an idle `MusicState` (QML contract: tolerate
/// unavailable player → `{"playing": false}`).
pub fn fetch_current() -> MusicState {
    let current = run_mpc(&["-f", "ARTIST=[%artist%] TITLE=[%title%] ALBUM=[%album%] TIME=[%time%]", "current"]);
    let status = run_mpc(&["status"]);
    let (c, s) = match (current, status) {
        (Ok(c), Ok(s)) => (c, s),
        _ => return MusicState::default(),
    };
    parse_mpc_output(&c, &s)
}

#[derive(Debug)]
pub enum MusicError {
    /// `mpc` binary not found or subprocess failed to spawn.
    Io(std::io::Error),
    /// mpc exited non-zero.
    Mpc { stderr: String },
}

impl From<std::io::Error> for MusicError {
    fn from(e: std::io::Error) -> Self {
        MusicError::Io(e)
    }
}

impl std::fmt::Display for MusicError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            MusicError::Io(e) => write!(f, "failed to run mpc: {e}"),
            MusicError::Mpc { stderr } => write!(f, "mpc error: {stderr}"),
        }
    }
}

impl std::error::Error for MusicError {}

#[cfg(test)]
mod tests {
    use super::*;

    const STATUS_PLAYING: &str = "volume:100%   repeat: off   random: off   single: off   consume: off\n[playing] #1/1   3:11/4:10 (76%)\nvolume: 100%   repeat: off   random: off";
    const STATUS_PAUSED: &str = "volume:80%   repeat: off   random: off   single: off   consume: off\n[paused] #1/1   0:42/3:15 (21%)\n";
    const STATUS_IDLE: &str = "volume:100%   repeat: off   random: off   single: off   consume: off\n";

    #[test]
    fn current_line_full() {
        let (a, t, al) = parse_current_line(
            "ARTIST=[Muse] TITLE=[Uprising] ALBUM=[The Resistance] TIME=[4:10]",
        );
        assert_eq!(a, "Muse");
        assert_eq!(t, "Uprising");
        assert_eq!(al, "The Resistance");
    }

    #[test]
    fn current_line_empty_when_idle() {
        let (a, t, al) = parse_current_line("");
        assert_eq!((a.as_str(), t.as_str(), al.as_str()), ("", "", ""));
    }

    #[test]
    fn current_line_missing_field() {
        // Album omitted from the format match → empty, not a panic.
        let (a, t, al) = parse_current_line("ARTIST=[x] TITLE=[y] TIME=[1:00]");
        assert_eq!(a, "x");
        assert_eq!(t, "y");
        assert_eq!(al, "");
    }

    #[test]
    fn current_line_artist_with_brackets_is_truncated() {
        // mpc does not escape `]`; first-close wins (matches QML regex).
        let (a, _, _) = parse_current_line("ARTIST=[A[B] C] TITLE=[t] ALBUM=[a]");
        assert_eq!(a, "A[B");
    }

    #[test]
    fn status_playing() {
        let (playing, elapsed, total) = parse_status_block(STATUS_PLAYING);
        assert!(playing);
        assert_eq!(elapsed, 3 * 60 + 11);
        assert_eq!(total, 4 * 60 + 10);
    }

    #[test]
    fn status_paused() {
        let (playing, elapsed, total) = parse_status_block(STATUS_PAUSED);
        assert!(!playing);
        assert_eq!(elapsed, 42);
        assert_eq!(total, 3 * 60 + 15);
    }

    #[test]
    fn status_idle() {
        let (playing, elapsed, total) = parse_status_block(STATUS_IDLE);
        assert!(!playing);
        assert_eq!(elapsed, 0);
        assert_eq!(total, 0);
    }

    #[test]
    fn full_parse_playing() {
        let s = parse_mpc_output(
            "ARTIST=[Muse] TITLE=[Uprising] ALBUM=[The Resistance] TIME=[4:10]",
            STATUS_PLAYING,
        );
        assert!(s.playing);
        assert_eq!(s.track, "Uprising");
        assert_eq!(s.artist, "Muse");
        assert_eq!(s.album, "The Resistance");
        assert_eq!(s.elapsed, 191);
        assert_eq!(s.total, 250);
    }

    #[test]
    fn full_parse_idle() {
        let s = parse_mpc_output("", STATUS_IDLE);
        assert!(!s.playing);
        assert_eq!(s.track, "");
        assert_eq!(s.elapsed, 0);
        assert_eq!(s.total, 0);
    }

    #[test]
    fn format_time_boundaries() {
        assert_eq!(format_time(0), "0:00");
        assert_eq!(format_time(59), "0:59");
        assert_eq!(format_time(60), "1:00");
        assert_eq!(format_time(61), "1:01");
        assert_eq!(format_time(600), "10:00");
        assert_eq!(format_time(3661), "61:01");
    }

    #[test]
    fn parse_field_does_not_panic_on_garbage() {
        let (a, t, al) = parse_current_line("no brackets here");
        assert_eq!((a.as_str(), t.as_str(), al.as_str()), ("", "", ""));
        let (playing, e, tt) = parse_status_block("garbage\nno time\n");
        assert!(!playing);
        assert_eq!((e, tt), (0, 0));
    }
}