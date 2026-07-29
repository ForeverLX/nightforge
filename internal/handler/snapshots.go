package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// SnapshotInfo contains L7 versioning/snapshot metadata.
type SnapshotInfo struct {
	LatestSnapshot  string `json:"latest_snapshot"`
	TotalSnapshots  int    `json:"total_snapshots"`
	Rollbacks       int    `json:"rollbacks"`
}

// HandleSnapshots returns L7 snapshot history.
func HandleSnapshots(w http.ResponseWriter, r *http.Request) {
	info := SnapshotInfo{
		LatestSnapshot: findLatestSnapshot(),
		TotalSnapshots: countSnapshots(),
		Rollbacks:      countRollbacks(),
	}
	writeJSON(w, http.StatusOK, info)
}

func findLatestSnapshot() string {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, "Documents", "ai-lab-vault", "40-Memory", "snapshots")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	var latest time.Time
	var latestName string
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		if info.ModTime().After(latest) {
			latest = info.ModTime()
			latestName = e.Name()
		}
	}
	if latestName == "" {
		return ""
	}
	return latest.UTC().Format(time.RFC3339)
}

func countSnapshots() int {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, "Documents", "ai-lab-vault", "40-Memory", "snapshots")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	return len(entries)
}

func countRollbacks() int {
	home, _ := os.UserHomeDir()
	dir := filepath.Join(home, "rollbacks")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	return len(entries)
}
