package handler

import (
	"encoding/json"
	"net/http"

	"github.com/ForeverLX/nightforge/internal/collector"
)

// HandleHealth returns the latest health snapshot and 24h history.
func HandleHealth(w http.ResponseWriter, r *http.Request) {
	current, history := collector.GetHealth()
	if current.Timestamp == "" {
		writeJSON(w, http.StatusOK, map[string]any{
			"current": nil,
			"history": []any{},
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"current": current,
		"history": history,
	})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v) //nolint:errcheck
}
