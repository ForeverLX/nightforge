package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

// Layer describes one layer of the 10-layer harness.
type Layer struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Status      string `json:"status"`
	Description string `json:"description,omitempty"`
}

var layers = []Layer{
	{ID: "L1", Name: "Hardware/Infra", Status: "complete", Description: "Arch Linux, Niri, NightForge"},
	{ID: "L2", Name: "Gateway/Cost", Status: "not-applicable", Description: "Flat-rate pricing, no tracking needed"},
	{ID: "L3", Name: "Routing", Status: "complete", Description: "v5 routing matrix in AGENTS.md"},
	{ID: "L4", Name: "Failure Mining", Status: "complete", Description: "549 entries classified"},
	{ID: "L5", Name: "Proposal Engine", Status: "complete"},
	{ID: "L6", Name: "Validation Gate", Status: "complete", Description: "5 gate rules"},
	{ID: "L7", Name: "Versioning & Rollback", Status: "complete"},
	{ID: "L8", Name: "Routing Matrix", Status: "complete"},
	{ID: "L9", Name: "Benefit Measurement", Status: "not-designed"},
	{ID: "L10", Name: "Weight Update", Status: "not-designed"},
}

// HandleLayers returns the 10-layer implementation status with proposals and gates detail.
func HandleLayers(w http.ResponseWriter, r *http.Request) {
	home, _ := os.UserHomeDir()
	base := filepath.Join(home, "Github", "nightforge", "data")

	proposals := readJSONFile(filepath.Join(base, "proposals", "proposals.json"))
	gates := readJSONFile(filepath.Join(base, "gates", "gates.json"))
	failures := readJSONFile(filepath.Join(base, "failures", "failures.json"))

	writeJSON(w, http.StatusOK, map[string]any{
		"layers":    layers,
		"proposals": proposals,
		"gates":     gates,
		"failures":  failures,
	})
}

func readJSONFile(path string) any {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var v any
	if err := json.Unmarshal(data, &v); err != nil {
		return nil
	}
	return v
}
