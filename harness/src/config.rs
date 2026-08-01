use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub terminal: TerminalConfig,
    pub panes: PanesConfig,
    pub agents: std::collections::HashMap<String, AgentConfig>,
    #[serde(default)]
    pub keybindings: Keybindings,
    #[serde(default)]
    pub gnhf: GnhfConfig,
    #[serde(default)]
    pub no_mistakes: NoMistakesConfig,
}

#[derive(Debug, Deserialize, Clone)]
pub struct TerminalConfig {
    #[serde(default = "default_font")]
    pub font: String,
    #[serde(default = "default_font_size")]
    pub font_size: u32,
    #[serde(default = "default_theme")]
    pub theme: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct PanesConfig {
    pub default_layout: Vec<PaneGroup>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct PaneGroup {
    #[serde(rename = "type")]
    pub group_type: String,
    pub panes: Vec<String>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct AgentConfig {
    pub command: Vec<String>,
    #[serde(default)]
    pub env: std::collections::HashMap<String, String>,
    #[serde(default = "default_working_dir")]
    pub working_dir: String,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct Keybindings {
    #[serde(default = "default_new_tab")]
    pub new_tab: String,
    #[serde(default = "default_close_pane")]
    pub close_pane: String,
    #[serde(default = "default_next_pane")]
    pub next_pane: String,
    #[serde(default = "default_prev_pane")]
    pub prev_pane: String,
    #[serde(default = "default_split_horizontal")]
    pub split_horizontal: String,
    #[serde(default = "default_split_vertical")]
    pub split_vertical: String,
    #[serde(default = "default_gnhf_run")]
    pub gnhf_run: String,
    #[serde(default = "default_gate_run")]
    pub gate_run: String,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct GnhfConfig {
    #[serde(default = "default_gnhf_agent")]
    pub agent: String,
    #[serde(default = "default_max_iterations")]
    pub max_iterations: u32,
    #[serde(default)]
    pub stop_condition: String,
    #[serde(default = "default_worktree_dir")]
    pub worktree_dir: String,
}

#[derive(Debug, Deserialize, Clone, Default)]
pub struct NoMistakesConfig {
    #[serde(default = "default_repo_path")]
    pub repo_path: String,
    #[serde(default = "default_gate_on_merge")]
    pub gate_on_merge: bool,
}

// Default value functions
fn default_font() -> String { "JetBrainsMono Nerd Font".to_string() }
fn default_font_size() -> u32 { 13 }
fn default_theme() -> String { "dark".to_string() }
fn default_working_dir() -> String { "~".to_string() }
fn default_new_tab() -> String { "Ctrl+Shift+T".to_string() }
fn default_close_pane() -> String { "Ctrl+Shift+W".to_string() }
fn default_next_pane() -> String { "Ctrl+Tab".to_string() }
fn default_prev_pane() -> String { "Ctrl+Shift+Tab".to_string() }
fn default_split_horizontal() -> String { "Ctrl+Shift+H".to_string() }
fn default_split_vertical() -> String { "Ctrl+Shift+V".to_string() }
fn default_gnhf_run() -> String { "Ctrl+G".to_string() }
fn default_gate_run() -> String { "Ctrl+M".to_string() }
fn default_gnhf_agent() -> String { "acp:omp".to_string() }
fn default_max_iterations() -> u32 { 200 }
fn default_worktree_dir() -> String { "~/Documents/ai-lab-vault-gnhf-worktrees".to_string() }
fn default_repo_path() -> String { "~/Documents/ai-lab-vault".to_string() }
fn default_gate_on_merge() -> bool { true }

pub fn load() -> Result<Config> {
    let config_path = dirs::config_dir()
        .context("Failed to get config directory")?
        .join("harness")
        .join("config.toml");

    if !config_path.exists() {
        tracing::warn!("Config not found at {:?}, using defaults", config_path);
        return Ok(default_config());
    }

    let content = std::fs::read_to_string(&config_path)
        .context(format!("Failed to read config at {:?}", config_path))?;

    let config: Config = toml::from_str(&content)
        .context("Failed to parse config")?;

    Ok(config)
}

fn default_config() -> Config {
    let mut agents = std::collections::HashMap::new();
    agents.insert("omp".to_string(), AgentConfig {
        command: vec!["omp".to_string(), "--profile".to_string(), "cr1ms0n".to_string(), "acp".to_string()],
        env: std::collections::HashMap::new(),
        working_dir: "~".to_string(),
    });

    Config {
        terminal: TerminalConfig {
            font: default_font(),
            font_size: default_font_size(),
            theme: default_theme(),
        },
        panes: PanesConfig {
            default_layout: vec![
                PaneGroup {
                    group_type: "horizontal".to_string(),
                    panes: vec!["omp".to_string()],
                },
            ],
        },
        agents,
        keybindings: Keybindings::default(),
        gnhf: GnhfConfig::default(),
        no_mistakes: NoMistakesConfig::default(),
    }
}
