package api

import (
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/ForeverLX/nightforge/internal/collector"
	"github.com/ForeverLX/nightforge/internal/collector/model"
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

// ---- usage ----

func usageHandler(w http.ResponseWriter, r *http.Request) {
	usage := collector.GetUsage()
	writeJSON(w, http.StatusOK, map[string]any{
		"records": usage,
	})
}

// ---- layers ----

func layersHandler(w http.ResponseWriter, r *http.Request) {
	layers := collector.GetLayers()
	writeJSON(w, http.StatusOK, map[string]any{"layers": layers})
}

func failuresHandler(w http.ResponseWriter, r *http.Request) {
	reports := collector.GetFailureReports()
	if reports == nil {
		reports = []model.FailureReport{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"failures": reports})
}

func proposalsHandler(w http.ResponseWriter, r *http.Request) {
	proposals := collector.GetProposals()
	if proposals == nil {
		proposals = []model.Proposal{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"proposals": proposals})
}

func gatesHandler(w http.ResponseWriter, r *http.Request) {
	gates := collector.GetGates()
	if gates == nil {
		gates = []model.GateResult{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"gates": gates})
}

func snapshotsHandler(w http.ResponseWriter, r *http.Request) {
	snapshots := collector.GetSnapshots()
	if snapshots == nil {
		snapshots = []model.Snapshot{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"snapshots": snapshots})
}

// ---- alerts ----

func alertsHandler(w http.ResponseWriter, r *http.Request) {
	health := collector.GetHealth()
	services := collector.GetServices()
	alerts := collector.GetAlerts(health, services)
	if alerts == nil {
		alerts = []model.ActiveAlert{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"alerts":       alerts,
		"alert_count":  len(alerts),
		"generated_at": time.Now().UTC().Format(time.RFC3339),
	})
}

// ---- history ----

func historyHandler(w http.ResponseWriter, r *http.Request) {
	days := 1
	if d := r.URL.Query().Get("days"); d != "" {
		if v, err := strconv.Atoi(d); err == nil && v > 0 && v <= 30 {
			days = v
		}
	}
	points := collector.GetHistory(days)
	if points == nil {
		points = []model.HistoryPoint{}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"points":       points,
		"count":        len(points),
		"generated_at": time.Now().UTC().Format(time.RFC3339),
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
