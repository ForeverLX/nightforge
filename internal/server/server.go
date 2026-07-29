package server

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"time"

	"github.com/ForeverLX/nightforge/internal/handler"
)

// New creates an http.Handler with all routes registered.
func New(frontend embed.FS) http.Handler {
	mux := http.NewServeMux()

	// API endpoints
	mux.HandleFunc("GET /api/v1/health", handler.HandleHealth)
	mux.HandleFunc("GET /api/v1/layers", handler.HandleLayers)
	mux.HandleFunc("GET /api/v1/sessions", handler.HandleSessions)
	mux.HandleFunc("GET /api/v1/snapshots", handler.HandleSnapshots)
	mux.HandleFunc("GET /api/v1/routes", handler.HandleRoutes)
	mux.HandleFunc("GET /api/v1/cost", handler.HandleCost)

	// Static frontend
	frontendFS, err := fs.Sub(frontend, "frontend")
	if err != nil {
		log.Fatalf("failed to sub frontend: %v", err)
	}
	mux.Handle("GET /", http.FileServer(http.FS(frontendFS)))

	return withMiddleware(mux)
}

func withMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// CORS for local dev
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)

		// Logging
		log.Printf("%s %s %s %s", r.Method, r.URL.Path, time.Since(start), r.RemoteAddr)
	})
}
