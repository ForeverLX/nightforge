package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

const tidFile = "data/tid/m3tid.json"

// HandleTID returns the M3TID threat-informed defense maturity assessment.
func HandleTID(w http.ResponseWriter, r *http.Request) {
	home, err := os.UserHomeDir()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "cannot determine home dir"})
		return
	}
	path := filepath.Join(home, "Github", "nightforge", tidFile)
	data, err := os.ReadFile(path)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": "no M3TID assessment yet — run go run ./cmd/m3tid"}) //nolint:errcheck
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(data) //nolint:errcheck
}
