mod agent;
mod config;
mod herdr;
mod presets;
mod terminal;

use anyhow::Result;
use tracing_subscriber::{fmt, EnvFilter};

fn main() -> Result<()> {
    // Initialize logging
    fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("gn=debug".parse()?))
        .init();

    tracing::info!("Starting GN harness v{}", env!("CARGO_PKG_VERSION"));

    // Load config
    let config = config::load()?;
    tracing::debug!("Config loaded: {:?}", config);

    // Run terminal
    terminal::run(config)?;

    Ok(())
}
