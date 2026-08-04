package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

const tokensFile = "data/tokens/current.json"

// HandleCost returns aggregated token usage and cost data.
func HandleCost(w http.ResponseWriter, r *http.Request) {
	home, err := os.UserHomeDir()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "cannot determine home dir"})
		return
	}
	path := filepath.Join(home, "Github", "nightforge", tokensFile)
	data, err := os.ReadFile(path)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "no token data yet — run scripts/harness/token-tracker.sh"}) //nolint:errcheck
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(data) //nolint:errcheck
}
