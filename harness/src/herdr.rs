use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;

const HERDR_SOCKET: &str = "/tmp/herdr.sock";

#[derive(Debug, Serialize, Deserialize)]
pub struct PaneInfo {
    pub id: String,
    pub name: String,
    pub status: String,
    pub agent: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct HerdrResponse {
    pub success: bool,
    pub data: Option<serde_json::Value>,
    pub error: Option<String>,
}

pub struct HerdrClient {
    socket_path: PathBuf,
}

impl HerdrClient {
    pub fn new() -> Self {
        HerdrClient {
            socket_path: PathBuf::from(HERDR_SOCKET),
        }
    }

    pub async fn list_panes(&self) -> Result<Vec<PaneInfo>> {
        let response = self.send_command("pane list").await?;
        let panes: Vec<PaneInfo> = serde_json::from_value(
            response.data.unwrap_or(serde_json::Value::Null)
        ).context("Failed to parse pane list")?;
        Ok(panes)
    }

    pub async fn create_pane(&self, name: &str, agent: &str) -> Result<PaneInfo> {
        let cmd = format!("pane create --name {} --agent {}", name, agent);
        let response = self.send_command(&cmd).await?;
        let pane: PaneInfo = serde_json::from_value(
            response.data.unwrap_or(serde_json::Value::Null)
        ).context("Failed to parse created pane")?;
        Ok(pane)
    }

    pub async fn destroy_pane(&self, id: &str) -> Result<()> {
        let cmd = format!("pane destroy {}", id);
        self.send_command(&cmd).await?;
        Ok(())
    }

    pub async fn send_input(&self, pane_id: &str, input: &str) -> Result<()> {
        let cmd = format!("pane input {} {}", pane_id, input);
        self.send_command(&cmd).await?;
        Ok(())
    }

    pub async fn read_output(&self, pane_id: &str) -> Result<String> {
        let cmd = format!("pane output {}", pane_id);
        let response = self.send_command(&cmd).await?;
        Ok(response.data
            .and_then(|v| v.as_str().map(String::from))
            .unwrap_or_default())
    }

    async fn send_command(&self, command: &str) -> Result<HerdrResponse> {
        let mut stream = UnixStream::connect(&self.socket_path)
            .await
            .context("Failed to connect to herdr socket")?;

        // Send command
        stream.write_all(format!("{}\n", command).as_bytes()).await?;

        // Read response
        let reader = BufReader::new(stream);
        let mut lines = reader.lines();

        if let Some(line) = lines.next_line().await? {
            let response: HerdrResponse = serde_json::from_str(&line)
                .context("Failed to parse herdr response")?;
            Ok(response)
        } else {
            anyhow::bail!("No response from herdr")
        }
    }
}

impl Default for HerdrClient {
    fn default() -> Self {
        Self::new()
    }
}
