package handler

import "net/http"

// Route describes a model routing entry.
type Route struct {
	Role     string `json:"role"`
	Model    string `json:"model"`
	Provider string `json:"provider"`
}

var routes = []Route{
	{Role: "Hermes BRAIN", Model: "deepseek-v4-flash", Provider: "opencode-go"},
	{Role: "OMP EXECUTOR", Model: "deepseek-v4-flash", Provider: "opencode-go"},
	{Role: "Subagents", Model: "deepseek-v4-flash-free", Provider: "opencode-zen"},
	{Role: "Pi/gnhf", Model: "ornith-1.0-9b-Q4_K_M", Provider: "local-llama"},
}

// HandleRoutes returns the active model routing table.
func HandleRoutes(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"routes": routes,
	})
}
