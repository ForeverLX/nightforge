package handler

import (
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

// SnapshotInfo contains L7 versioning/snapshot metadata.
type SnapshotInfo struct {
	LatestSnapshot string          `json:"latest_snapshot"`
	TotalSnapshots int             `json:"total_snapshots"`
	Rollbacks      int             `json:"rollbacks"`
	History        []SnapshotEntry `json:"history,omitempty"`
}

// SnapshotEntry is a single snapshot event.
type SnapshotEntry struct {
	Name      string `json:"name"`
	Timestamp string `json:"timestamp"`
	Label     string `json:"label"`
	Type      string `json:"type"`
}

// RollbackEntry is a single rollback event.
type RollbackEntry struct {
	Snapshot  string `json:"snapshot"`
	Timestamp string `json:"timestamp"`
	Reason    string `json:"reason"`
}

type snapshotLog struct {
	Snapshots []SnapshotEntry  `json:"snapshots"`
	Rollbacks []RollbackEntry  `json:"rollbacks"`
}

// HandleSnapshots returns L7 snapshot history from snapshot-log.json.
func HandleSnapshots(w http.ResponseWriter, r *http.Request) {
	home, _ := os.UserHomeDir()
	path := filepath.Join(home, "Github", "nightforge", "data", "snapshots", "snapshot-log.json")

	data, err := os.ReadFile(path)
	if err != nil {
		writeJSON(w, http.StatusOK, SnapshotInfo{
			LatestSnapshot: "",
			TotalSnapshots: 0,
			Rollbacks:      0,
			History:        []SnapshotEntry{},
		})
		return
	}

	var log snapshotLog
	if err := json.Unmarshal(data, &log); err != nil {
		writeJSON(w, http.StatusOK, SnapshotInfo{
			LatestSnapshot: "",
			TotalSnapshots: 0,
			Rollbacks:      0,
			History:        []SnapshotEntry{},
		})
		return
	}

	snaps := log.Snapshots
	if snaps == nil {
		snaps = []SnapshotEntry{}
	}
	rolls := log.Rollbacks
	if rolls == nil {
		rolls = []RollbackEntry{}
	}

	latest := ""
	if len(snaps) > 0 {
		latest = snaps[len(snaps)-1].Timestamp
	}

	// Build history from snapshot entries
	history := make([]SnapshotEntry, len(snaps))
	for i, s := range snaps {
		history[i] = s
	}

	writeJSON(w, http.StatusOK, SnapshotInfo{
		LatestSnapshot: latest,
		TotalSnapshots: len(snaps),
		Rollbacks:      len(rolls),
		History:        history,
	})
}
