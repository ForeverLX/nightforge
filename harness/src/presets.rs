use std::collections::HashMap;
use crate::config::AgentConfig;

/// Built-in agent presets for common configurations.
/// These can be overridden via config.toml [agents.<name>] sections.

pub fn default_presets() -> HashMap<String, AgentConfig> {
    let mut presets = HashMap::new();

    presets.insert("omp".to_string(), AgentConfig {
        command: vec![
            "omp".to_string(),
            "--profile".to_string(),
            "cr1ms0n".to_string(),
            "acp".to_string(),
        ],
        env: HashMap::new(),
        working_dir: "~".to_string(),
    });

    presets.insert("hermes".to_string(), AgentConfig {
        command: vec![
            "hermes".to_string(),
            "acp".to_string(),
            "--profile".to_string(),
            "cr1ms0n".to_string(),
        ],
        env: HashMap::new(),
        working_dir: "~".to_string(),
    });

    presets.insert("zero".to_string(), AgentConfig {
        command: vec!["zero".to_string(), "acp".to_string()],
        env: HashMap::new(),
        working_dir: "~".to_string(),
    });

    // c4 — C2 management, direct integration (not through OMP)
    presets.insert("c4".to_string(), AgentConfig {
        command: vec!["c4".to_string(), "status".to_string()],
        env: HashMap::new(),
        working_dir: "~".to_string(),
    });

    presets
}
