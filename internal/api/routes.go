package api

import (
	"io/fs"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	nightforge "github.com/CR1MS0N-Operator/nightforge"
)

// NewRouter creates the chi router with all API routes, SSE, and static files.
func NewRouter() http.Handler {
	r := chi.NewRouter()

	// Global middleware.
	r.Use(recoveryMiddleware)
	r.Use(loggingMiddleware)
	r.Use(corsMiddleware)

	// Compress responses (built-in chi middleware).
	r.Use(middleware.Compress(5, "application/json", "text/event-stream"))

	// API v1 routes.
	r.Route("/api/v1", func(r chi.Router) {
		r.Get("/health", healthHandler)
		r.Get("/services", servicesHandler)
		r.Get("/ports", portsHandler)
		r.Get("/tasks", tasksHandler)
		r.Get("/analysis", analysisHandler)
		r.Get("/logs", logsHandler)
		r.Get("/usage", usageHandler)
		r.Get("/layers", layersHandler)
		r.Get("/layers/l4/failures", failuresHandler)
		r.Get("/layers/l5/proposals", proposalsHandler)
		r.Get("/layers/l6/gates", gatesHandler)
		r.Get("/layers/l7/snapshots", snapshotsHandler)
		r.Get("/alerts", alertsHandler)
		r.Get("/history", historyHandler)
	})

	// SSE hub.
	hub := NewHub()
	r.Get("/api/v1/events", hub.ServeHTTP)

	// Static files from embedded web/ directory.
	webContent, err := fs.Sub(nightforge.WebFS, "web")
	if err != nil {
		panic("embedded web/ directory not found: " + err.Error())
	}
	fileServer := http.FileServer(http.FS(webContent))
	r.Get("/*", func(w http.ResponseWriter, r *http.Request) {
		// Strip the leading "/" so chi's wildcard captures everything.
		// chi strips the route pattern prefix, so in /* the captured path
		// includes the leading /. FileServer needs that stripped.
		fileServer.ServeHTTP(w, r)
	})

	return r
}
