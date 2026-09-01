package api

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector"
)

// Hub manages SSE client connections and broadcasts collector snapshots.
type Hub struct {
	mu         sync.RWMutex
	clients    map[chan []byte]struct{}
	register   chan chan []byte
	unregister chan chan []byte
}

// NewHub creates an SSE hub and starts the background polling goroutine.
func NewHub() *Hub {
	h := &Hub{
		clients:    make(map[chan []byte]struct{}),
		register:   make(chan chan []byte),
		unregister: make(chan chan []byte),
	}
	go h.run()
	return h
}

// snapshot collects all dashboard data into a combined JSON payload.
func snapshot() []byte {
	data := map[string]any{
		"health":   collector.GetHealth(),
		"services": collector.GetServices(),
		"ports":    collector.GetPorts(),
		"tasks":    collector.GetTasks(),
		"analysis": collector.GetAnalysis(),
		"layers":   collector.GetLayers(),
		"alerts":   collector.GetAlerts(collector.GetHealth(), collector.GetServices()),
	}

	// Log files list (non-fatal if it fails).
	if logs, err := collector.GetLogFiles(); err == nil {
		data["logs"] = logs
	}

	b, err := json.Marshal(data)
	if err != nil {
		log.Printf("sse: marshal snapshot: %v", err)
		return []byte(`{"error":"marshal failed"}`)
	}
	return b
}

// run is the hub event loop. It polls collectors every 10 seconds and
// re-broadcasts the latest snapshot to every connected client.
func (h *Hub) run() {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	// Send initial snapshot immediately.
	initial := snapshot()
	mu := sync.Mutex{} // serialise broadcast writes

	for {
		select {
		case ch := <-h.register:
			h.mu.Lock()
			h.clients[ch] = struct{}{}
			h.mu.Unlock()
			// Send initial snapshot to new client.
			go func() {
				select {
				case ch <- initial:
				default:
				}
			}()

		case ch := <-h.unregister:
			h.mu.Lock()
			delete(h.clients, ch)
			close(ch)
			h.mu.Unlock()

		case <-ticker.C:
			payload := snapshot()
			h.mu.RLock()
			mu.Lock()
			for ch := range h.clients {
				// Non-blocking send: drop slow clients.
				select {
				case ch <- payload:
				default:
				}
			}
			mu.Unlock()
			h.mu.RUnlock()
		}
	}
}

// ServeHTTP handles an SSE connection. It registers the client's channel,
// streams events, and cleans up on disconnect.
func (h *Hub) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	ch := make(chan []byte, 32)
	h.register <- ch

	defer func() {
		h.unregister <- ch
	}()

	ctx := r.Context()
	for {
		select {
		case <-ctx.Done():
			return
		case payload, ok := <-ch:
			if !ok {
				return
			}
			fmt.Fprintf(w, "data: %s\n\n", payload)
			flusher.Flush()
		}
	}
}
