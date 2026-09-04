// Package config provides TETHER harness control plane configuration.
package config

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
)

// Config holds TETHER harness control plane configuration.
type Config struct {
	ListenAddr string         `json:"listen_addr"`
	DataDir    string         `json:"data_dir"`
	Herdr      HerdrConfig    `json:"herdr"`
	Langfuse   LangfuseConfig `json:"langfuse"`
	Agents     []AgentConfig  `json:"agents"`
	Notify     NotifyConfig   `json:"notify"`
}

// HerdrConfig holds herdr terminal runtime connection settings.
type HerdrConfig struct {
	SocketPath string `json:"socket_path"`
	Enabled    bool   `json:"enabled"`
}

// LangfuseConfig holds Langfuse tracing connection settings.
type LangfuseConfig struct {
	OTLPEndpoint string `json:"otlp_endpoint"`
	Enabled      bool   `json:"enabled"`
}

// AgentConfig defines a known agent for service discovery.
type AgentConfig struct {
	Name    string `json:"name"`
	Command string `json:"command"`
	Type    string `json:"type"` // "hermes", "omp", "pi", "subagent"
}

// NotifyConfig controls notification behavior.
type NotifyConfig struct {
	Enabled bool   `json:"enabled"`
	Method  string `json:"method"` // "desktop", "log", "both"
}

// DefaultConfig returns the default configuration.
func DefaultConfig() *Config {
	home, _ := os.UserHomeDir()
	return &Config{
		ListenAddr: "127.0.0.1:9191",
		DataDir:    filepath.Join(home, "nightforge", "data"),
		Herdr: HerdrConfig{
			SocketPath: filepath.Join(home, ".local", "share", "herdr", "herdr.sock"),
			Enabled:    true,
		},
		Langfuse: LangfuseConfig{
			OTLPEndpoint: "http://127.0.0.1:31744",
			Enabled:      false,
		},
		Agents: []AgentConfig{
			{Name: "hermes", Command: "hermes", Type: "hermes"},
			{Name: "omp", Command: "omp", Type: "omp"},
			{Name: "pi", Command: "pi", Type: "pi"},
		},
		Notify: NotifyConfig{
			Enabled: true,
			Method:  "desktop",
		},
	}
}

// Load reads configuration from ~/.config/tether/config.json,
// falling back to defaults for missing fields.
func Load() *Config {
	cfg := DefaultConfig()

	home, _ := os.UserHomeDir()
	configPath := filepath.Join(home, ".config", "tether", "config.json")

	data, err := os.ReadFile(configPath)
	if err != nil {
		log.Printf("config: using defaults (no config file at %s)", configPath)
		return cfg
	}

	if err := json.Unmarshal(data, cfg); err != nil {
		log.Printf("config: parse error, using defaults: %v", err)
		return cfg
	}

	log.Printf("config: loaded from %s", configPath)
	return cfg
}

// Save writes the current configuration to disk.
func (c *Config) Save() error {
	home, _ := os.UserHomeDir()
	configDir := filepath.Join(home, ".config", "tether")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return err
	}

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filepath.Join(configDir, "config.json"), data, 0644)
}
