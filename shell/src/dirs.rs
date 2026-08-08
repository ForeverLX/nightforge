//! QsDirs — per-widget directory resolver (S187 widget spec §1.1).
//!
//! Mirrors the reference `Caching.qml` / `caching.sh` contract so the wgpu
//! shell is a drop-in for the Quickshell dir layout during migration.
//!
//! | dir   | default                              | env override      |
//! |-------|--------------------------------------|-------------------|
//! | cache | `$XDG_CACHE_HOME/quickshell/<name>`  | `QS_CACHE_<NAME>` |
//! | state | `$XDG_STATE_HOME/quickshell/<name>`  | `QS_STATE_<NAME>` |
//! | run   | `$XDG_RUNTIME_DIR/quickshell/<name>` | `QS_RUN_<NAME>`   |
//! | log   | `<run>/logs`                         | —                 |
//!
//! Resolvers only — no `mkdir` per call; callers create dirs once at startup.

use std::env;
use std::path::PathBuf;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QsDirs {
    pub cache: PathBuf,
    pub state: PathBuf,
    pub run: PathBuf,
    pub log: PathBuf,
}

impl QsDirs {
    pub fn for_widget(name: &str) -> Self {
        let upper = name.to_uppercase();
        let cache = env::var(format!("QS_CACHE_{upper}")).map(PathBuf::from).unwrap_or_else(|_| {
            base_dir("XDG_CACHE_HOME", "~/.cache").join("quickshell").join(name)
        });
        let state = env::var(format!("QS_STATE_{upper}")).map(PathBuf::from).unwrap_or_else(|_| {
            base_dir("XDG_STATE_HOME", "~/.local/state").join("quickshell").join(name)
        });
        let run = env::var(format!("QS_RUN_{upper}")).map(PathBuf::from).unwrap_or_else(|_| {
            base_dir("XDG_RUNTIME_DIR", "/tmp").join("quickshell").join(name)
        });
        let log = run.join("logs");
        QsDirs { cache, state, run, log }
    }
}

fn base_dir(env_key: &str, default: &str) -> PathBuf {
    if let Ok(v) = env::var(env_key) {
        if !v.is_empty() {
            return PathBuf::from(v);
        }
    }
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(default.replace('~', &home))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    /// Tests mutate process-global env vars; serialize them (cargo runs
    /// test fns in parallel threads by default).
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn set(vars: &[(&str, &str)]) {
        for (k, v) in vars {
            env::set_var(k, v);
        }
    }

    fn unset(vars: &[&str]) {
        for k in vars {
            env::remove_var(k);
        }
    }

    #[test]
    fn dir_resolution_contract() {
        let _guard = ENV_LOCK.lock().unwrap();
        // capture originals
        let originals: Vec<(String, Option<String>)> = [
            "QS_CACHE_MUSIC",
            "QS_STATE_MUSIC",
            "QS_RUN_MUSIC",
            "QS_CACHE_NETWORK",
            "XDG_CACHE_HOME",
            "XDG_STATE_HOME",
            "XDG_RUNTIME_DIR",
            "HOME",
        ]
        .iter()
        .map(|k| (k.to_string(), env::var(k).ok()))
        .collect();

        // 1. env overrides win
        set(&[
            ("QS_RUN_MUSIC", "/run/nightforge/music"),
            ("XDG_RUNTIME_DIR", "/run/user/1000"),
            ("XDG_CACHE_HOME", "/tmp/xdg-cache"),
            ("XDG_STATE_HOME", "/tmp/xdg-state"),
        ]);
        let d = QsDirs::for_widget("music");
        assert_eq!(d.run, PathBuf::from("/run/nightforge/music"));
        assert_eq!(d.log, PathBuf::from("/run/nightforge/music/logs"));
        assert_eq!(d.cache, PathBuf::from("/tmp/xdg-cache/quickshell/music"));

        // 2. defaults use XDG
        unset(&["QS_CACHE_NETWORK", "QS_STATE_NETWORK", "QS_RUN_NETWORK"]);
        let d = QsDirs::for_widget("network");
        assert_eq!(d.cache, PathBuf::from("/tmp/xdg-cache/quickshell/network"));
        assert_eq!(d.state, PathBuf::from("/tmp/xdg-state/quickshell/network"));
        assert_eq!(d.run, PathBuf::from("/run/user/1000/quickshell/network"));

        // restore
        for (k, v) in originals {
            match v {
                Some(v) => env::set_var(k, v),
                None => env::remove_var(k),
            }
        }
    }
}
