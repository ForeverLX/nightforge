use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, Command};
use tokio::sync::mpsc;

use crate::config::AgentConfig;

/// ACP JSON-RPC request sent to agent
#[derive(Debug, Serialize)]
pub struct AcpRequest {
    pub jsonrpc: String,
    pub id: u64,
    pub method: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub params: Option<serde_json::Value>,
}

/// ACP JSON-RPC response from agent
#[derive(Debug, Deserialize)]
pub struct AcpResponse {
    pub jsonrpc: String,
    pub id: Option<u64>,
    #[serde(default)]
    pub result: Option<serde_json::Value>,
    #[serde(default)]
    pub error: Option<AcpError>,
}

#[derive(Debug, Deserialize)]
pub struct AcpError {
    pub code: i64,
    pub message: String,
    #[serde(default)]
    pub data: Option<serde_json::Value>,
}

/// Messages between agent process and harness
#[derive(Debug)]
pub enum AgentEvent {
    /// Output line from agent stdout
    Output(String),
    /// Agent process exited
    Exited { code: Option<i32> },
    /// ACP response received
    Response(AcpResponse),
    /// Error from agent I/O
    Error(String),
}

/// Manages a single agent child process with ACP communication
pub struct AgentProcess {
    pub name: String,
    child: Option<Child>,
    stdin_tx: Option<mpsc::Sender<Vec<u8>>>,
    event_rx: mpsc::Receiver<AgentEvent>,
    request_id: u64,
}

impl AgentProcess {
    /// Spawn an agent process from config
    pub async fn spawn(name: &str, config: &AgentConfig) -> Result<Self> {
        let mut cmd = Command::new(&config.command[0]);
        if config.command.len() > 1 {
            cmd.args(&config.command[1..]);
        }

        // Set environment variables
        for (key, value) in &config.env {
            cmd.env(key, value);
        }

        // Set working directory
        if config.working_dir != "~" {
            let work_dir = dirs::home_dir()
                .context("Failed to get home dir")?
                .join(config.working_dir.trim_start_matches("~/"));
            cmd.current_dir(work_dir);
        }

        // Pipe stdio
        cmd.stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        let mut child = cmd.spawn()
            .context(format!("Failed to spawn agent '{}'", name))?;

        // Get handles before moving into tasks
        let stdin = child.stdin.take()
            .context("Failed to get stdin")?;
        let stdout = child.stdout.take()
            .context("Failed to get stdout")?;
        let stderr = child.stderr.take()
            .context("Failed to get stderr")?;

        // Channel for stdin writes
        let (stdin_tx, mut stdin_rx) = mpsc::channel::<Vec<u8>>(32);
        let (event_tx, event_rx) = mpsc::channel::<AgentEvent>(64);

        // stdin writer task
        tokio::spawn(async move {
            let mut stdin = stdin;
            while let Some(data) = stdin_rx.recv().await {
                if stdin.write_all(&data).await.is_err() {
                    break;
                }
                if stdin.flush().await.is_err() {
                    break;
                }
            }
        });

        // stdout reader task
        let event_tx_stdout = event_tx.clone();
        let name_stdout = name.to_string();
        tokio::spawn(async move {
            let mut reader = BufReader::new(stdout);
            let mut line = String::new();
            loop {
                line.clear();
                match reader.read_line(&mut line).await {
                    Ok(0) => break,
                    Ok(_) => {
                        let trimmed = line.trim().to_string();
                        if !trimmed.is_empty() {
                            if let Ok(resp) = serde_json::from_str::<AcpResponse>(&trimmed) {
                                let _ = event_tx_stdout.send(AgentEvent::Response(resp)).await;
                            } else {
                                let _ = event_tx_stdout.send(AgentEvent::Output(trimmed)).await;
                            }
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        // stderr reader task (log as output)
        let event_tx_stderr = event_tx.clone();
        tokio::spawn(async move {
            let mut reader = BufReader::new(stderr);
            let mut line = String::new();
            loop {
                line.clear();
                match reader.read_line(&mut line).await {
                    Ok(0) => break,
                    Ok(_) => {
                        let trimmed = line.trim().to_string();
                        if !trimmed.is_empty() {
                            let _ = event_tx_stderr.send(AgentEvent::Output(
                                format!("[{name_stdout}] {trimmed}")
                            )).await;
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        Ok(AgentProcess {
            name: name.to_string(),
            child: Some(child),
            stdin_tx: Some(stdin_tx),
            event_rx,
            request_id: 1,
        })
    }

    /// Send an ACP request and wait for response
    pub async fn request(&mut self, method: &str, params: Option<serde_json::Value>) -> Result<AcpResponse> {
        let id = self.request_id;
        self.request_id += 1;

        let req = AcpRequest {
            jsonrpc: "2.0".to_string(),
            id,
            method: method.to_string(),
            params,
        };

        let mut json = serde_json::to_string(&req)?;
        json.push('\n');

        let tx = self.stdin_tx.as_ref()
            .context("Agent stdin not available")?;

        tx.send(json.into_bytes()).await
            .context("Failed to send to agent stdin")?;

        // Wait for response with matching id
        let timeout = tokio::time::timeout(
            std::time::Duration::from_secs(30),
            self.read_response(id),
        );

        match timeout.await {
            Ok(Ok(resp)) => Ok(resp),
            Ok(Err(e)) => Err(e),
            Err(_) => anyhow::bail!("Agent '{}' timed out waiting for response", self.name),
        }
    }

    /// Read events from the agent
    pub async fn recv(&mut self) -> Option<AgentEvent> {
        self.event_rx.recv().await
    }

    /// Try to receive an event without blocking
    pub fn try_recv(&mut self) -> Option<AgentEvent> {
        self.event_rx.try_recv().ok()
    }

    async fn read_response(&mut self, expected_id: u64) -> Result<AcpResponse> {
        loop {
            match self.event_rx.recv().await {
                Some(AgentEvent::Response(resp)) if resp.id == Some(expected_id) => {
                    return Ok(resp);
                }
                Some(AgentEvent::Response(_)) => continue,
                Some(AgentEvent::Output(_)) => continue,
                Some(AgentEvent::Exited { code }) => {
                    anyhow::bail!("Agent '{}' exited with code {:?}", self.name, code);
                }
                Some(AgentEvent::Error(e)) => {
                    anyhow::bail!("Agent '{}' error: {}", self.name, e);
                }
                None => {
                    anyhow::bail!("Agent '{}' channel closed", self.name);
                }
            }
        }
    }

    /// Send raw input to agent stdin
    pub async fn send_input(&mut self, data: &[u8]) -> Result<()> {
        let tx = self.stdin_tx.as_ref()
            .context("Agent stdin not available")?;
        tx.send(data.to_vec()).await
            .context("Failed to send input to agent")?;
        Ok(())
    }

    /// Gracefully stop the agent
    pub async fn stop(&mut self) -> Result<()> {
        if let Some(child) = &mut self.child {
            // Drop stdin to signal EOF
            self.stdin_tx.take();

            // Give it 5 seconds to exit gracefully
            let _ = tokio::time::timeout(
                std::time::Duration::from_secs(5),
                child.wait(),
            ).await;

            // Force kill if still running
            if let Ok(None) = child.try_wait() {
                let _ = child.kill().await;
            }
        }
        self.child = None;
        Ok(())
    }

    /// Check if agent is still running
    pub fn is_running(&self) -> bool {
        self.child.is_some()
    }
}

impl Drop for AgentProcess {
    fn drop(&mut self) {
        if let Some(child) = &mut self.child {
            let _ = child.start_kill();
        }
    }
}
