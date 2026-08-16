package handler

import "net/http"

// Route describes a model routing entry.
type Route struct {
	Role     string `json:"role"`
	Model    string `json:"model"`
	Provider string `json:"provider"`
}

// routes is the authoritative model/provider mapping for the S210 stack
// (source of truth per AGENTS.md, served at GET /api/v1/routes and consumed
// by GET /api/v1/status). Deprecated agents OMP/Zero/Buzz and the
// decommissioned opengateway provider are removed; local lane is now the
// Qwen models (Bonsai name retired).
var routes = []Route{
	{Role: "Hermes BRAIN", Model: "hermes-brain", Provider: "hermes (profile home)"},
	{Role: "dsh EXECUTOR", Model: "deepseek-v4-flash", Provider: "cline-pass (:3080)"},
	{Role: "Pi Agent LOCAL LANES", Model: "Qwen3.8-27B / Qwen3-1.7B", Provider: "local-llama (:18234 quality / :18236 aux)"},
}

// HandleRoutes returns the active model routing table.
func HandleRoutes(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"routes": routes,
	})
}
