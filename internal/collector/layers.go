package collector

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/ForeverLX/nightforge/internal/collector/model"
)

// vaultScriptsDir is the root of the AI Lab Vault scripts directory.
var vaultScriptsDir = os.ExpandEnv("$HOME/Documents/ai-lab-vault/80-Operations/scripts")

// vaultMemoryDir is the 40-Memory directory for reports and proposals.
var vaultMemoryDir = os.ExpandEnv("$HOME/Documents/ai-lab-vault/40-Memory")

// vaultSnapshotsDir is the config-snapshots directory.
var vaultSnapshotsDir = os.ExpandEnv("$HOME/Documents/ai-lab-vault/80-Operations/config-snapshots")

// layerDef describes each of the 10 architecture layers.
type layerDef struct {
	ID          int
	Name        string
	Description string
	ScriptPath  string // empty means "always implemented"
}

var layerDefs = []layerDef{
	{ID: 1, Name: "Config & Architecture", Description: "System configuration and architecture docs", ScriptPath: ""},
	{ID: 2, Name: "Documentation", Description: "Project documentation and runbooks", ScriptPath: ""},
	{ID: 3, Name: "Templates & Patterns", Description: "Reusable templates and design patterns", ScriptPath: ""},
	{ID: 4, Name: "Failure Mining", Description: "L4 failure detection and classification", ScriptPath: "l4/failure-miner.sh"},
	{ID: 5, Name: "Proposal Engine", Description: "L5 proposal generation and ranking", ScriptPath: "l5/proposal-engine.sh"},
	{ID: 6, Name: "Validation Gates", Description: "L6 pre-apply validation checks", ScriptPath: "l6/validation-gate/gate-runner.sh"},
	{ID: 7, Name: "Versioning & Rollback", Description: "L7 config snapshots and rollback", ScriptPath: "l7/snapshot-config.sh"},
	{ID: 8, Name: "Communication Gateway", Description: "API gateway and cost tracking", ScriptPath: "gateway/openrouter-cost.sh"},
	{ID: 9, Name: "Weight Optimization", Description: "L9 model weight optimization", ScriptPath: "l9-optimize.sh"},
	{ID: 10, Name: "Auto Adaptation", Description: "L10 autonomous adaptation engine", ScriptPath: "l10-adapt.sh"},
}

// GetLayers checks each layer's script/directory existence and returns statuses.
func GetLayers() []model.Layer {
	var layers []model.Layer
	for _, def := range layerDefs {
		l := model.Layer{
			ID:          def.ID,
			Name:        def.Name,
			Description: def.Description,
			Status:      "implemented",
		}

		if def.ScriptPath != "" {
			fullPath := filepath.Join(vaultScriptsDir, def.ScriptPath)
			if _, err := os.Stat(fullPath); err == nil {
				l.Status = "implemented"
				if fi, err2 := os.Stat(fullPath); err2 == nil {
					l.LastRun = fi.ModTime().UTC().Format(time.RFC3339)
				}
			} else {
				// Check if a parent directory exists at least.
				dir := filepath.Dir(fullPath)
				if _, err := os.Stat(dir); err == nil {
					l.Status = "not_implemented"
				} else {
					l.Status = "not_implemented"
				}
			}
		}

		layers = append(layers, l)
	}
	return layers
}

// GetFailureReports lists L4 failure reports from the failure-reports directory.
func GetFailureReports() []model.FailureReport {
	dir := filepath.Join(vaultMemoryDir, "failure-reports")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var reports []model.FailureReport
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".yaml") && !strings.HasSuffix(entry.Name(), ".yml") {
			// Also check JSON files
			if !strings.HasSuffix(entry.Name(), ".json") {
				continue
			}
		}

		reportPath := filepath.Join(dir, entry.Name())
		data, err := os.ReadFile(reportPath)
		if err != nil {
			continue
		}

		// Try to extract meaningful data from the report.
		// Reports are YAML or JSON; parse what we can.
		content := string(data)
		r := model.FailureReport{
			ID:      entry.Name(),
			Summary: firstNLines(content, 1),
		}

		// Try to count failure entries (look for YAML list items or "category:" keys).
		r.Count = strings.Count(content, "\n- ")
		if r.Count == 0 {
			r.Count = strings.Count(content, "category:")
		}

		// Extract category from filename or content.
		r.Category = extractCategory(content, entry.Name())

		reports = append(reports, r)
	}
	return reports
}

// GetProposals lists L5 proposals from the proposals directory.
func GetProposals() []model.Proposal {
	dir := filepath.Join(vaultMemoryDir, "proposals")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}

	var proposals []model.Proposal
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		if !strings.HasSuffix(entry.Name(), ".yaml") && !strings.HasSuffix(entry.Name(), ".yml") && !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}

		propPath := filepath.Join(dir, entry.Name())
		data, err := os.ReadFile(propPath)
		if err != nil {
			continue
		}

		content := string(data)
		p := model.Proposal{
			ID:     entry.Name(),
			Status: "pending",
		}

		// Extract fields from YAML-like content.
		p.Title = extractYAMLValue(content, "title")
		if p.Title == "" {
			p.Title = entry.Name()
		}

		if v, ok := extractYAMLInt(content, "impact"); ok {
			p.ImpactScore = v
		}
		if v, ok := extractYAMLInt(content, "effort"); ok {
			p.EffortScore = v
		}
		if s := extractYAMLValue(content, "status"); s != "" {
			p.Status = s
		}

		proposals = append(proposals, p)
	}
	return proposals
}

// GetGates runs the L6 gate-runner.sh in babysitter mode and parses results.
func GetGates() []model.GateResult {
	gateRunner := filepath.Join(vaultScriptsDir, "l6/validation-gate/gate-runner.sh")
	if _, err := os.Stat(gateRunner); err != nil {
		return nil
	}

	cmd := exec.Command("bash", gateRunner)
	cmd.Env = append(os.Environ(), "BABYSITTER_MODE=1")
	out, err := cmd.Output()
	if err != nil {
		// Gate runner returns non-zero on failures; output is still valid.
		_ = err
	}

	return parseGateOutput(string(out))
}

// GetSnapshots lists L7 config snapshots from the snapshots directory.
func GetSnapshots() []model.Snapshot {
	entries, err := os.ReadDir(vaultSnapshotsDir)
	if err != nil {
		return nil
	}

	var snapshots []model.Snapshot
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		snapPath := filepath.Join(vaultSnapshotsDir, entry.Name())
		size := dirSize(snapPath)

		// Extract timestamp from directory name: snapshot-20260726T120000Z-abcdef123456
		ts := ""
		parts := strings.SplitN(entry.Name(), "-", 3)
		if len(parts) >= 2 {
			ts = parts[1]
		}

		snapshots = append(snapshots, model.Snapshot{
			ID:        entry.Name(),
			Timestamp: ts,
			Path:      snapPath,
			Size:      size,
		})
	}
	return snapshots
}

// ---- internal helpers ----

// firstNLines returns the first n lines of s.
func firstNLines(s string, n int) string {
	lines := strings.SplitN(s, "\n", n+1)
	if len(lines) > n {
		return strings.Join(lines[:n], "\n")
	}
	return s
}

// extractCategory tries to find a category label in YAML content or filename.
func extractCategory(content, filename string) string {
	// Try YAML key.
	for _, key := range []string{"category:", "category ", "type:", "class:"} {
		if idx := strings.Index(content, key); idx >= 0 {
			rest := content[idx+len(key):]
			rest = strings.TrimSpace(rest)
			if end := strings.IndexAny(rest, "\n\r#"); end >= 0 {
				rest = rest[:end]
			}
			rest = strings.TrimSpace(rest)
			rest = strings.Trim(rest, "\"'")
			if rest != "" {
				return rest
			}
		}
	}
	// Fallback: use filename without extension.
	return strings.TrimSuffix(filename, filepath.Ext(filename))
}

// extractYAMLValue extracts a simple top-level YAML key value.
func extractYAMLValue(content, key string) string {
	for _, prefix := range []string{key + ":", key + " "} {
		if idx := strings.Index(content, prefix); idx >= 0 {
			rest := content[idx+len(prefix):]
			rest = strings.TrimSpace(rest)
			if end := strings.IndexAny(rest, "\n\r#"); end >= 0 {
				rest = rest[:end]
			}
			rest = strings.TrimSpace(rest)
			rest = strings.Trim(rest, "\"'")
			return rest
		}
	}
	return ""
}

// extractYAMLInt extracts a simple top-level YAML integer value.
func extractYAMLInt(content, key string) (int, bool) {
	for _, prefix := range []string{key + ":", key + " "} {
		if idx := strings.Index(content, prefix); idx >= 0 {
			rest := strings.TrimSpace(content[idx+len(prefix):])
			if end := strings.IndexAny(rest, "\n\r#"); end >= 0 {
				rest = rest[:end]
			}
			rest = strings.TrimSpace(rest)
			if v, err := strconv.Atoi(rest); err == nil {
				return v, true
			}
		}
	}
	return 0, false
}

// parseGateOutput parses BABYSITTER_MODE=1 output from gate-runner.sh.
// Expected format: lines like "Gate: check-name → PASS (0.123s)" or "Gate: check-name → FAIL (0.456s): error msg"
func parseGateOutput(output string) []model.GateResult {
	var results []model.GateResult
	for _, line := range strings.Split(output, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		r := model.GateResult{Status: "UNKNOWN"}

		// Parse "Gate: name → STATUS (Xs)" format.
		if strings.HasPrefix(line, "Gate:") {
			rest := strings.TrimPrefix(line, "Gate:")
			rest = strings.TrimSpace(rest)

			// Split on → arrow.
			if arrowIdx := strings.Index(rest, "\u2192"); arrowIdx >= 0 {
				r.Name = strings.TrimSpace(rest[:arrowIdx])
				rest = strings.TrimSpace(rest[arrowIdx+len("\u2192"):])
			} else if arrowIdx = strings.Index(rest, "->"); arrowIdx >= 0 {
				r.Name = strings.TrimSpace(rest[:arrowIdx])
				rest = strings.TrimSpace(rest[arrowIdx+2:])
			} else {
				r.Name = rest
			}

			// Extract status.
			if strings.HasPrefix(rest, "PASS") {
				r.Status = "PASS"
			} else if strings.HasPrefix(rest, "FAIL") {
				r.Status = "FAIL"
			} else if strings.HasPrefix(rest, "SKIP") {
				r.Status = "SKIP"
			}

			// Extract duration in parentheses.
			if paren := strings.Index(rest, "("); paren >= 0 {
				durStr := rest[paren+1:]
				if end := strings.Index(durStr, "s"); end >= 0 {
					durStr = durStr[:end]
				} else if end := strings.Index(durStr, ")"); end >= 0 {
					durStr = durStr[:end]
				}
				if v, err := strconv.ParseFloat(strings.TrimSpace(durStr), 64); err == nil {
					r.Duration = v
				}
			}

			// Extract error after ": " following status.
			if colon := strings.Index(rest, "]: "); colon >= 0 {
				r.Error = strings.TrimSpace(rest[colon+3:])
			} else if colon = strings.Index(rest, ": "); colon >= 0 {
				// Only treat as error if after a status keyword.
				afterParen := rest
				if paren := strings.Index(rest, ")"); paren >= 0 {
					afterParen = strings.TrimSpace(rest[paren+1:])
				}
				if strings.HasPrefix(afterParen, ": ") {
					r.Error = strings.TrimSpace(afterParen[2:])
				}
			}
		} else if strings.Contains(line, "PASS") || strings.Contains(line, "FAIL") {
			// Check for "check-name: PASS" or "✓ check-name" patterns.
			r.Name = line
			if strings.Contains(line, "PASS") || strings.Contains(line, "✓") || strings.Contains(line, "OK") {
				r.Status = "PASS"
			} else if strings.Contains(line, "FAIL") || strings.Contains(line, "✗") || strings.Contains(line, "ERROR") {
				r.Status = "FAIL"
			}
		} else {
			// Try JSON array of gate results.
			if strings.HasPrefix(line, "[") || strings.HasPrefix(line, "{") {
				var parsed []model.GateResult
				if err := json.Unmarshal([]byte(line), &parsed); err == nil {
					results = append(results, parsed...)
					continue
				}
				var single model.GateResult
				if err := json.Unmarshal([]byte(line), &single); err == nil && single.Name != "" {
					results = append(results, single)
					continue
				}
			}
			continue
		}

		if r.Name != "" {
			results = append(results, r)
		}
	}
	return results
}

// dirSize recursively computes the total size of files in a directory.
func dirSize(path string) int64 {
	var size int64
	filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	return size
}
