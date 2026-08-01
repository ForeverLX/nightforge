package collector

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/ForeverLX/nightforge-dashboard/internal/collector/model"
)

// historyDir stores time-series health snapshots.
var historyDir = os.ExpandEnv("$HOME/Github/nightforge/data/history")

// HistoryRetentionDays is how long we keep history files.
const HistoryRetentionDays = 7

var historyMu sync.Mutex

// historyFilePath returns the path for today's history file.
func historyFilePath() string {
	today := time.Now().Format("2006-01-02")
	return filepath.Join(historyDir, fmt.Sprintf("health-%s.jsonl", today))
}

// RecordHealthSnapshot appends a health snapshot to today's history file.
// Creates the history directory and file if needed.
func RecordHealthSnapshot(health model.Health) {
	historyMu.Lock()
	defer historyMu.Unlock()

	if err := os.MkdirAll(historyDir, 0755); err != nil {
		log.Printf("history: mkdir: %v", err)
		return
	}

	pt := model.HistoryPoint{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Health:    health,
	}

	line, err := json.Marshal(pt)
	if err != nil {
		log.Printf("history: marshal: %v", err)
		return
	}

	f, err := os.OpenFile(historyFilePath(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("history: open: %v", err)
		return
	}
	defer f.Close()

	if _, err := f.Write(append(line, '\n')); err != nil {
		log.Printf("history: write: %v", err)
	}
}

// GetHistory returns history points for the last N days.
// If days is 0 or negative, returns all available history.
func GetHistory(days int) []model.HistoryPoint {
	historyMu.Lock()
	defer historyMu.Unlock()

	if err := os.MkdirAll(historyDir, 0755); err != nil {
		return nil
	}

	entries, err := os.ReadDir(historyDir)
	if err != nil {
		return nil
	}

	cutoff := time.Now().AddDate(0, 0, -days)
	var result []model.HistoryPoint

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".jsonl") {
			continue
		}

		// Parse date from filename: health-YYYY-MM-DD.jsonl
		if days > 0 {
			dateStr := strings.TrimPrefix(strings.TrimSuffix(e.Name(), ".jsonl"), "health-")
			t, err := time.Parse("2006-01-02", dateStr)
			if err != nil || t.Before(cutoff) {
				continue
			}
		}

		data, err := os.ReadFile(filepath.Join(historyDir, e.Name()))
		if err != nil {
			continue
		}

		for _, line := range strings.Split(string(data), "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			var pt model.HistoryPoint
			if err := json.Unmarshal([]byte(line), &pt); err != nil {
				continue
			}
			result = append(result, pt)
		}
	}

	// Sort chronologically
	sort.Slice(result, func(i, j int) bool {
		return result[i].Timestamp < result[j].Timestamp
	})

	return result
}

// PurgeHistory removes history files older than retentionDays.
func PurgeHistory() {
	historyMu.Lock()
	defer historyMu.Unlock()

	entries, err := os.ReadDir(historyDir)
	if err != nil {
		return
	}

	cutoff := time.Now().AddDate(0, 0, -HistoryRetentionDays)
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".jsonl") {
			continue
		}
		dateStr := strings.TrimPrefix(strings.TrimSuffix(e.Name(), ".jsonl"), "health-")
		t, err := time.Parse("2006-01-02", dateStr)
		if err != nil {
			continue
		}
		if t.Before(cutoff) {
			os.Remove(filepath.Join(historyDir, e.Name()))
			log.Printf("history: purged %s", e.Name())
		}
	}
}
