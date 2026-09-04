package collector

import (
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector/model"
)

// DiscoveredService represents a dynamically discovered service.
type DiscoveredService struct {
	Name      string `json:"name"`
	Type      string `json:"type"`
	Status    string `json:"status"` // "connected", "disconnected", "unknown"
	Address   string `json:"address,omitempty"`
	PID       int    `json:"pid,omitempty"`
	StartTime string `json:"start_time,omitempty"`
}

// DiscoverHerdr checks if herdr is running and accessible via its socket.
func DiscoverHerdr(socketPath string) DiscoveredService {
	svc := DiscoveredService{
		Name:   "herdr",
		Type:   "terminal-runtime",
		Status: "disconnected",
	}

	if socketPath == "" {
		home, _ := os.UserHomeDir()
		socketPath = filepath.Join(home, ".local", "share", "herdr", "herdr.sock")
	}

	if _, err := os.Stat(socketPath); err != nil {
		return svc
	}

	conn, err := net.DialTimeout("unix", socketPath, 2*time.Second)
	if err != nil {
		return svc
	}
	defer conn.Close()

	svc.Status = "connected"
	svc.Address = socketPath
	return svc
}

// DiscoverLangfuse checks if Langfuse is reachable at the OTLP endpoint.
func DiscoverLangfuse(endpoint string) DiscoveredService {
	svc := DiscoveredService{
		Name:   "langfuse",
		Type:   "tracing",
		Status: "disconnected",
	}

	if endpoint == "" {
		endpoint = "http://127.0.0.1:31744"
	}

	conn, err := net.DialTimeout("tcp", "127.0.0.1:31744", 2*time.Second)
	if err != nil {
		return svc
	}
	defer conn.Close()

	svc.Status = "connected"
	svc.Address = endpoint
	return svc
}

// DiscoverAgents checks which agents are available on the system.
func DiscoverAgents(agents []AgentDef) []DiscoveredService {
	var discovered []DiscoveredService

	for _, agent := range agents {
		svc := DiscoveredService{
			Name:   agent.Name,
			Type:   agent.Type,
			Status: "disconnected",
		}

		// Check if agent binary is in PATH
		if path, err := findBinary(agent.Command); err == nil {
			svc.Address = path
			svc.Status = "available"
		}

		discovered = append(discovered, svc)
	}

	return discovered
}

// AgentDef defines an agent for discovery purposes.
type AgentDef struct {
	Name    string
	Command string
	Type    string
}

// findBinary checks if a binary exists in PATH.
func findBinary(name string) (string, error) {
	// Check common paths
	for _, dir := range []string{"/usr/bin", "/usr/local/bin", filepath.Join(os.Getenv("HOME"), ".local", "bin")} {
		path := filepath.Join(dir, name)
		if info, err := os.Stat(path); err == nil && info.Mode().IsRegular() {
			return path, nil
		}
	}

	// Try exec.LookPath
	if path, err := os.Stat(name); err == nil && path.Mode().IsRegular() {
		return name, nil
	}

	return "", os.ErrNotExist
}

// GetAllDiscoveredServices runs all discovery checks and returns combined results.
func GetAllDiscoveredServices(herdrSocket, langfuseEndpoint string, agentDefs []AgentDef) []DiscoveredService {
	var all []DiscoveredService

	all = append(all, DiscoverHerdr(herdrSocket))
	all = append(all, DiscoverLangfuse(langfuseEndpoint))
	all = append(all, DiscoverAgents(agentDefs)...)

	return all
}
