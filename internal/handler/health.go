package handler

import (
	"encoding/json"
	"net/http"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector"
)

// HandleHealth returns the latest health snapshot, 24h history, and daily summary.
func HandleHealth(w http.ResponseWriter, r *http.Request) {
	current, history := collector.GetHealthHistory()
	if current.Timestamp == "" {
		writeJSON(w, http.StatusOK, map[string]any{
			"current":        nil,
			"history":        []any{},
			"daily_summary":  collector.GetDailySummary(),
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"current":       current,
		"history":       history,
		"daily_summary": collector.GetDailySummary(),
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}
