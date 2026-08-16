package handler

import "net/http"

// Route describes a model routing entry.
type Route struct {
	Role     string `json:"role"`
	Model    string `json:"model"`
	Provider string `json:"provider"`
}

var routes = []Route{
	{Role: "Hermes BRAIN", Model: "mimo-v2.5-pro", Provider: "opengateway"},
	{Role: "dsh EXECUTOR", Model: "deepseek-v4-flash", Provider: "dsh"},
	{Role: "Subagents", Model: "deepseek-v4-flash-free", Provider: "opencode-zen"},
	{Role: "Local", Model: "Qwen3.8-27B-Q6_K", Provider: "local-llama (:18234, GPU -ngl 15)"},
}

// HandleRoutes returns the active model routing table.
func HandleRoutes(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"routes": routes,
	})
}
