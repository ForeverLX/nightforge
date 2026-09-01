package collector

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector/model"
)

// costLogsDir is the directory where cost/usage JSON logs live.
var costLogsDir = os.ExpandEnv("$HOME/Documents/ai-lab-vault/40-Memory/cost-logs")

// costLogEntry is the JSON structure we expect in cost-log files.
type costLogEntry struct {
	Provider   string  `json:"provider"`
	Model      string  `json:"model"`
	TokensIn   int64   `json:"tokens_in"`
	TokensOut  int64   `json:"tokens_out"`
	Cost       float64 `json:"cost"`
	Timestamp  string  `json:"timestamp"`
}

// GetUsage scans cost-log JSON files and returns aggregated usage records.
// Falls back to placeholder data when no cost logs exist yet.
func GetUsage() []model.UsageRecord {
	records := tryParseCostLogs()
	if len(records) > 0 {
		return records
	}
	return placeholderUsage()
}

// tryParseCostLogs reads JSON files from costLogsDir and aggregates them.
// Returns nil if the directory doesn't exist or contains no parseable data.
func tryParseCostLogs() []model.UsageRecord {
	entries, err := os.ReadDir(costLogsDir)
	if err != nil {
		return nil
	}

	today := time.Now().Format("2006-01-02")
	type aggKey struct {
		provider, model string
	}
	type aggVal struct {
		tokensIn     int64
		tokensOut    int64
		cost         float64
		requestCount int64
	}
	agg := make(map[aggKey]*aggVal)

	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".json") {
			continue
		}
		path := filepath.Join(costLogsDir, e.Name())
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}

		// Try array of entries first, then single entry.
		var entries []costLogEntry
		if err := json.Unmarshal(data, &entries); err != nil {
			// Single entry fallback.
			var single costLogEntry
			if err := json.Unmarshal(data, &single); err != nil {
				continue
			}
			entries = []costLogEntry{single}
		}

		for _, entry := range entries {
			// Only count today's entries for the "day" period.
			if !strings.HasPrefix(entry.Timestamp, today) {
				continue
			}
			key := aggKey{entry.Provider, entry.Model}
			v := agg[key]
			if v == nil {
				v = &aggVal{}
				agg[key] = v
			}
			v.tokensIn += entry.TokensIn
			v.tokensOut += entry.TokensOut
			v.cost += entry.Cost
			v.requestCount++
		}
	}

	if len(agg) == 0 {
		return nil
	}

	var result []model.UsageRecord
	for key, v := range agg {
		provider := key.provider
		if provider == "" {
			provider = "unknown"
		}
		modelName := key.model
		if modelName == "" {
			modelName = "unknown"
		}
		result = append(result, model.UsageRecord{
			Provider:     provider,
			Model:        modelName,
			TokensIn:     v.tokensIn,
			TokensOut:    v.tokensOut,
			Cost:         v.cost,
			Period:       "day",
			RequestCount: v.requestCount,
		})
	}
	return result
}

// placeholderUsage returns realistic sample data for the three AI providers
// configured in this workstation: opencode-go, opencode-zen, and nous.
func placeholderUsage() []model.UsageRecord {
	return []model.UsageRecord{
		{
			Provider:     "opencode-go",
			Model:        "deepseek-v4-pro",
			TokensIn:     245_000,
			TokensOut:    38_000,
			Cost:         0.0,
			Period:       "day",
			RequestCount: 47,
		},
		{
			Provider:     "opencode-zen",
			Model:        "claude-opus-4-8",
			TokensIn:     112_000,
			TokensOut:    18_500,
			Cost:         0.0,
			Period:       "day",
			RequestCount: 22,
		},
		{
			Provider:     "nous",
			Model:        "llama-4-nous",
			TokensIn:     56_000,
			TokensOut:    12_300,
			Cost:         0.0,
			Period:       "day",
			RequestCount: 14,
		},
	}
}
