package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Session represents an agent session.
type Session struct {
	ID        string `json:"id"`
	StartedAt string `json:"started_at"`
	Status    string `json:"status"`
	Model     string `json:"model,omitempty"`
}

// PiCostSession represents parsed cost data from a Pi session.
type PiCostSession struct {
	SessionFile string  `json:"session_file"`
	SessionID   string  `json:"session_id"`
	StartedAt   string  `json:"started_at"`
	EndedAt     string  `json:"ended_at,omitempty"`
	Title       string  `json:"title,omitempty"`
	Model       string  `json:"model,omitempty"`
	Provider    string  `json:"provider,omitempty"`
	API         string  `json:"api,omitempty"`
	TokensIn    int     `json:"tokens_in"`
	TokensOut   int     `json:"tokens_out"`
	TotalTokens int     `json:"total_tokens"`
	Cost        float64 `json:"cost"`
	MessageCount int    `json:"message_count"`
	ToolCalls   int     `json:"tool_calls"`
	LastStopReason string `json:"last_stop_reason,omitempty"`
	Errors      int     `json:"errors"`
}

func HandleSessions(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"hermes":   readHermesSessions(),
		"omp":      readOMPSessions(),
		"pi_costs": readPiCosts(),
	})
}

func readHermesSessions() []Session {
	home, _ := os.UserHomeDir()
	return readSessionDir(filepath.Join(home, ".hermes", "sessions"))
}

func readOMPSessions() []Session {
	home, _ := os.UserHomeDir()
	return readSessionDir(filepath.Join(home, ".omp", "agent", "sessions"))
}

func readSessionDir(dir string) []Session {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return []Session{}
	}

	sessions := make([]Session, 0)
	cutoff := time.Now().Add(-72 * time.Hour)

	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil || info.ModTime().Before(cutoff) {
			continue
		}
		s := Session{
			ID:        strings.TrimSuffix(e.Name(), filepath.Ext(e.Name())),
			StartedAt: info.ModTime().UTC().Format(time.RFC3339),
			Status:    inferStatus(e.Name()),
		}
		s.Model = extractModel(filepath.Join(dir, e.Name()))
		sessions = append(sessions, s)
	}
	return sessions
}

func inferStatus(name string) string {
	name = strings.ToLower(name)
	if strings.Contains(name, "active") || strings.HasSuffix(name, ".tmp") {
		return "active"
	}
	return "ended"
}

func extractModel(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	if len(data) > 4096 {
		data = data[:4096]
	}
	content := string(data)
	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if strings.Contains(line, `"model"`) || strings.Contains(line, "model:") {
			var obj map[string]any
			if json.Unmarshal([]byte(content), &obj) == nil {
				if m, ok := obj["model"]; ok {
					if s, ok := m.(string); ok {
						return s
					}
				}
			}
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				return strings.Trim(strings.TrimSpace(parts[1]), `"`)
			}
		}
	}
	return ""
}

func readPiCosts() []PiCostSession {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	path := filepath.Join(home, "Github", "nightforge", "data", "cost", "pi-costs.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var wrapper struct {
		Sessions []PiCostSession `json:"sessions"`
	}
	if err := json.Unmarshal(data, &wrapper); err != nil {
		return nil
	}
	return wrapper.Sessions
}
