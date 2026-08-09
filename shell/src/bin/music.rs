//! `nightforge-music` — print current MPD state as JSON.
//!
//! Rust replacement for the mpc-parsing half of `music_info.sh` /
//! `MpdClient.qml`. Runs the same two `mpc` queries and emits the same JSON
//! field contract (`playing`, `title`, `artist`, `album`, plus `elapsed`,
//! `total`). Idle/error → `{"playing": false, …}` (never non-zero exit).
//!
//! Drop-in for scripts that currently shell out to `mpc` for widget state.

use serde_json::json;
use std::process::ExitCode;

use nightforge_shell::music::{fetch_current, MusicState};

fn main() -> ExitCode {
    let s = fetch_current();
    print_json(&s);
    ExitCode::SUCCESS
}

fn print_json(s: &MusicState) {
    let out = json!({
        "playing": s.playing,
        "title": s.track,
        "artist": s.artist,
        "album": s.album,
        "elapsed": s.elapsed,
        "total": s.total,
    });
    println!("{out}");
}