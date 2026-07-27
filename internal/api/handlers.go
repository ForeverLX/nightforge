package api

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/ForeverLX/nightforge-dashboard/internal/collector"
)

// ---- health ----

func healthHandler(w http.ResponseWriter, r *http.Request) {
	h := collector.GetHealth()
	writeJSON(w, http.StatusOK, h)
}

// ---- services ----

func servicesHandler(w http.ResponseWriter, r *http.Request) {
	svcs := collector.GetServices()
	writeJSON(w, http.StatusOK, map[string]any{"services": svcs})
}

// ---- ports ----

func portsHandler(w http.ResponseWriter, r *http.Request) {
	ports := collector.GetPorts()
	writeJSON(w, http.StatusOK, map[string]any{"ports": ports})
}

// ---- tasks ----

func tasksHandler(w http.ResponseWriter, r *http.Request) {
	tasks := collector.GetTasks()
	writeJSON(w, http.StatusOK, map[string]any{"tasks": tasks})
}

// ---- analysis (cross-referenced summary) ----

func analysisHandler(w http.ResponseWriter, r *http.Request) {
	health := collector.GetHealth()
	services := collector.GetServices()
	ports := collector.GetPorts()
	tasks := collector.GetTasks()

	// Count services by status.
	up, down := 0, 0
	for _, s := range services {
		if s.Status == "UP" {
			up++
		} else {
			down++
		}
	}

	// Count tasks by status.
	taskSummary := map[string]int{}
	for _, t := range tasks {
		taskSummary[t.Status]++
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"health":       health,
		"service_up":   up,
		"service_down": down,
		"total_ports":  len(ports),
		"task_summary": taskSummary,
		"generated_at": time.Now().UTC().Format(time.RFC3339),
	})
}

// ---- logs ----

func logsHandler(w http.ResponseWriter, r *http.Request) {
	fileName := r.URL.Query().Get("file")

	if fileName == "" {
		// List all available log files.
		files, err := collector.GetLogFiles()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to list log files: "+err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"files": files})
		return
	}

	// View a specific log file. Resolve through GetLogFiles to prevent path traversal.
	files, err := collector.GetLogFiles()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to list log files")
		return
	}

	var filePath string
	for _, f := range files {
		if f.Name == fileName {
			filePath = f.Path
			break
		}
	}

	if filePath == "" {
		writeError(w, http.StatusNotFound, "log file not found: "+fileName)
		return
	}

	// Read last N lines (default 200).
	maxLines := 200
	if n := r.URL.Query().Get("lines"); n != "" {
		if v, err := strconv.Atoi(n); err == nil && v > 0 && v <= 2000 {
			maxLines = v
		}
	}

	lines, err := collector.GetLogLines(filePath, maxLines)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to read log file: "+err.Error())
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"file":  fileName,
		"lines": lines,
	})
}

// ---- usage (placeholder) ----

func usageHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"api_calls_today": 0,
		"bytes_served":    0,
		"uptime_seconds":  0,
		"note":            "usage tracking not yet implemented",
	})
}

// ---- helpers ----

// writeJSON marshals v to JSON and writes it with the given status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("handlers: json encode: %v", err)
	}
}

// writeError sends a JSON error response.
func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
