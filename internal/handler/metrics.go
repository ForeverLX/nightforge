package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector"
)

// requestsTotal counts every HTTP request served; exposed as
// agentgateway_requests_total so the observability stack's Grafana
// "24h Health History" panel (sum of agentgateway_requests_total) lights up.
var requestsTotal atomic.Uint64

// IncRequests is called by the server middleware once per request.
func IncRequests() {
	requestsTotal.Add(1)
}

// HandleMetrics serves Prometheus text exposition (format 0.0.4) for the
// harness domain. Hand-rolled on purpose: go.mod is intentionally
// dependency-free, and the metric set is small and data-file-backed.
func HandleMetrics(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")

	home, _ := os.UserHomeDir()
	base := filepath.Join(home, "Github", "nightforge", "data")

	var b strings.Builder

	// --- proposals / gates (L5/L6) ---
	proposals := map[string]any{}
	gates := map[string]any{}
	readJSON(filepath.Join(base, "gates", "gates.json"), &gates)
	readJSON(filepath.Join(base, "proposals", "proposals.json"), &proposals)

	var propSuccess, propFail float64
	if results, ok := gates["proposal_results"].([]any); ok {
		for _, raw := range results {
			m, _ := raw.(map[string]any)
			switch m["overall"] {
			case "pass":
				propSuccess++
			case "fail":
				propFail++
			}
		}
	}
	total := propSuccess + propFail
	if total > 0 {
		fmt.Fprintf(&b, "# HELP harness_proposals_total Proposals evaluated by the validation gate.\n# TYPE harness_proposals_total gauge\nharness_proposals_total %s\n", strconv.FormatFloat(total, 'f', -1, 64))
	}
	fmt.Fprintf(&b, "# HELP harness_proposals_success_total Proposals that passed all gates.\n# TYPE harness_proposals_success_total counter\nharness_proposals_success_total %s\n", strconv.FormatFloat(propSuccess, 'f', -1, 64))
	fmt.Fprintf(&b, "# HELP harness_proposals_failure_total Proposals rejected by at least one gate.\n# TYPE harness_proposals_failure_total counter\nharness_proposals_failure_total %s\n", strconv.FormatFloat(propFail, 'f', -1, 64))

	if gl, ok := gates["gates"].([]any); ok {
		for _, raw := range gl {
			m, _ := raw.(map[string]any)
			id, _ := m["id"].(string)
			if id == "" {
				continue
			}
			pass, _ := m["pass_count"].(float64)
			fail, _ := m["fail_count"].(float64)
			fmt.Fprintf(&b, "# HELP harness_gates_total Gate evaluation outcomes.\n# TYPE harness_gates_total counter\n")
			fmt.Fprintf(&b, "harness_gates_total{gate=%q,status=\"pass\"} %s\n", id, strconv.FormatFloat(pass, 'f', -1, 64))
			fmt.Fprintf(&b, "harness_gates_total{gate=%q,status=\"fail\"} %s\n", id, strconv.FormatFloat(fail, 'f', -1, 64))
		}
	}

	// --- failures (L4) ---
	failures := map[string]any{}
	readJSON(filepath.Join(base, "failures", "failures.json"), &failures)

	catCounts := map[string]float64{}
	if cats, ok := failures["categories"].([]any); ok {
		for _, raw := range cats {
			m, _ := raw.(map[string]any)
			if id, _ := m["id"].(string); id != "" {
				catCounts[id] = num(m["count"])
			}
		}
	}
	if len(catCounts) == 0 {
		if fl, ok := failures["failures"].([]any); ok {
			for _, raw := range fl {
				m, _ := raw.(map[string]any)
				c, _ := m["category"].(string)
				catCounts[c]++
			}
		}
	}
	if len(catCounts) > 0 {
		fmt.Fprintf(&b, "# HELP harness_failures_total Mined failure sessions by category.\n# TYPE harness_failures_total gauge\n")
		for _, c := range sortedKeys(catCounts) {
			fmt.Fprintf(&b, "harness_failures_total{category=%q} %s\n", c, strconv.FormatFloat(catCounts[c], 'f', -1, 64))
		}
	}

	// --- cost / tokens (L2) ---
	cost := map[string]any{}
	readJSON(filepath.Join(base, "tokens", "current.json"), &cost)
	if t, ok := cost["totals"].(map[string]any); ok {
		fmt.Fprintf(&b, "# HELP harness_sessions_total Agent sessions in the tracked window.\n# TYPE harness_sessions_total gauge\nharness_sessions_total %s\n", strconv.FormatFloat(num(t["total_sessions"]), 'f', -1, 64))
		fmt.Fprintf(&b, "# HELP harness_tokens_total Token usage by direction.\n# TYPE harness_tokens_total gauge\n")
		fmt.Fprintf(&b, "harness_tokens_total{direction=\"input\"} %s\n", strconv.FormatFloat(num(t["total_tokens_in"]), 'f', -1, 64))
		fmt.Fprintf(&b, "harness_tokens_total{direction=\"output\"} %s\n", strconv.FormatFloat(num(t["total_tokens_out"]), 'f', -1, 64))
		fmt.Fprintf(&b, "# HELP harness_cost_usd Estimated USD spend in the tracked window.\n# TYPE harness_cost_usd gauge\nharness_cost_usd %s\n", strconv.FormatFloat(num(t["total_cost_usd"]), 'f', -1, 64))
	}

	// --- per-model session counts (L8 routing visibility) ---
	pi := map[string]any{}
	readJSON(filepath.Join(base, "cost", "pi-costs.json"), &pi)
	modelCounts := map[string]float64{}
	if sessions, ok := pi["sessions"].([]any); ok {
		for _, raw := range sessions {
			m, _ := raw.(map[string]any)
			model, _ := m["model"].(string)
			if model == "" {
				model = "unknown"
			}
			modelCounts[model]++
		}
	}
	if len(modelCounts) > 0 {
		fmt.Fprintf(&b, "# HELP harness_llm_sessions_total Agent sessions by model.\n# TYPE harness_llm_sessions_total gauge\n")
		for _, m := range sortedKeys(modelCounts) {
			fmt.Fprintf(&b, "harness_llm_sessions_total{model=%q} %s\n", m, strconv.FormatFloat(modelCounts[m], 'f', -1, 64))
		}
	}

	// --- system health snapshot (single current value; node-exporter owns the time series) ---
	if cur, _ := collector.GetHealthHistory(); cur.Timestamp != "" {
		fmt.Fprintf(&b, "# HELP harness_health System health gauges from the latest harnessd snapshot.\n# TYPE harness_health gauge\n")
		fmt.Fprintf(&b, "harness_health{metric=\"mem_pct\"} %d\n", cur.Health.MemPct)
		fmt.Fprintf(&b, "harness_health{metric=\"load_1m\"} %g\n", cur.Health.Load[0])
		fmt.Fprintf(&b, "harness_health{metric=\"disk_root_pct\"} %d\n", cur.Health.DiskRootPct)
		fmt.Fprintf(&b, "harness_health{metric=\"gpu_mem_mb\"} %d\n", cur.Health.GPUMem)
	}

	fmt.Fprintf(&b, "# HELP agentgateway_requests_total HTTP requests served by harnessd.\n# TYPE agentgateway_requests_total counter\nagentgateway_requests_total{service=\"harnessd\"} %d\n", requestsTotal.Load())

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(b.String())) //nolint:errcheck
}

func readJSON(path string, dst any) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	_ = json.Unmarshal(data, dst)
}

func num(v any) float64 {
	switch n := v.(type) {
	case float64:
		return n
	case int:
		return float64(n)
	case int64:
		return float64(n)
	case string:
		f, _ := strconv.ParseFloat(n, 64)
		return f
	}
	return 0
}

func sortedKeys(m map[string]float64) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}
