package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ForeverLX/nightforge/internal/collector"
)

// HandleStatus returns a compact Omarchy status-chip payload derived from the
// live routing table (routes) and the collector health snapshot. GET-only,
// no side effects, fast — mirrors the health.go style but stays tiny.
func HandleStatus(w http.ResponseWriter, r *http.Request) {
	current, _ := collector.GetHealthHistory()

	status := "healthy"
	if current.Timestamp == "" {
		status = "offline"
	} else if current.Health.DiskRootPct >= 90 || current.Health.DiskHomePct >= 90 || current.Health.MemPct >= 90 {
		status = "degraded"
	}

	total := len(routes)
	brain, executor, local := 0, 0, 0
	for _, rt := range routes {
		switch {
		case strings.Contains(strings.ToLower(rt.Role), "brain"):
			brain++
		case strings.Contains(strings.ToLower(rt.Role), "executor"):
			executor++
		default:
			local++
		}
	}

	model := currentModelFromRoutes()

	ts := time.Now().UTC().Format(time.RFC3339)
	lastRun := ts
	if current.Timestamp != "" {
		lastRun = current.Timestamp
	} else if t := lastPiRun(); t != "" {
		lastRun = t
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"status": status,
		"agents": map[string]any{
			"brain":    brain,
			"executor": executor,
			"local":    local,
			"total":    total,
		},
		"queue": map[string]any{
			"pending":     0,
			"running":     queueRunningCount(status),
			"last_run_at": lastRun,
		},
		"model": map[string]any{
			"current":  model["current"],
			"provider": model["provider"],
			"endpoint": model["endpoint"],
		},
		"workspace": "nightforge",
		"timestamp": ts,
		"actions":   []string{"open-dashboard"},
	})
}

// currentModelFromRoutes returns the live serving model from the corrected
// routing table, preferring the local large lane (provider "local-*").
func currentModelFromRoutes() map[string]string {
	res := map[string]string{"current": "", "provider": "", "endpoint": ""}
	for _, rt := range routes {
		if strings.Contains(strings.ToLower(rt.Provider), "local") {
			res["current"] = rt.Model
			res["provider"] = rt.Provider
			if i := strings.Index(rt.Provider, ":"); i >= 0 && i+6 <= len(rt.Provider) {
				res["endpoint"] = "127.0.0.1" + rt.Provider[i:i+6] // e.g. ":18234"
			}
			break
		}
	}
	return res
}

// queueRunningCount reports how many agent lanes are actively serving, derived
// from the status (a live collector snapshot implies the coordinator is up).
func queueRunningCount(status string) int {
	if status == "offline" {
		return 0
	}
	return 1
}

// lastPiRun reads last_updated from the parsed Pi cost tree, if present.
func lastPiRun() string {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, "Github", "nightforge", "data", "cost", "pi-costs.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	var v struct {
		LastUpdated string `json:"last_updated"`
	}
	if json.Unmarshal(data, &v) == nil {
		return v.LastUpdated
	}
	return ""
}
