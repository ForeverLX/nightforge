//! NightForge shell — widget data-core library.
//!
//! The S187 migration ports QML widget logic into typed, unit-tested Rust
//! modules here. GUI code (the wgpu spike binary) lives in the crate root;
//! this lib holds the pure data layer so it is testable headlessly with
//! `cargo test` and reusable from the shell scene and any CLI subcommand.

pub mod music;