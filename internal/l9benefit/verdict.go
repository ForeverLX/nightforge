package l9benefit

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// Verdict is the L9 output written to data/benefit/<proposal-id>.json.
//
// It follows the design doc §5.4 before/after protocol. The stub currently
// always emits verdict "no_data" because no agent traces flow through
// Langfuse yet. The structure is the real, forward-compatible shape so that
// when traces flow (Phase 1) only the metric computation needs filling in.
type Verdict struct {
	Verdict     string    `json:"verdict"`               // no_data | accept | reject
	ProposalID  string    `json:"proposal_id,omitempty"` // empty => global/daily
	Reason      string    `json:"reason"`
	GeneratedAt time.Time `json:"generated_at"`
	// Window holds the observation window and what was actually available.
	Window struct {
		From          time.Time `json:"from"`
		To            time.Time `json:"to"`
		Observations  int       `json:"observations"`
		AgentTraces   int       `json:"agent_traces"`
		ManualSpans   int       `json:"manual_spans"`
		HasTraceData  bool      `json:"has_trace_data"`
	} `json:"window"`
	// Metrics is the reserved M1-M10 surface. All zero until traces flow.
	Metrics Metrics `json:"metrics"`
}

// Metrics is the design-doc §4 metric set. Fields are present so downstream
// L10 (weight update) and Grafana can bind to them before data exists.
type Metrics struct {
	M1TokenRatio       float64 `json:"m1_token_ratio"`
	M2BlowupFreq       int     `json:"m2_blowup_freq"`
	M3MedianRatio      float64 `json:"m3_median_ratio"`
	M4CacheAmp         float64 `json:"m4_cache_amplification"`
	M5SessionSuccess   float64 `json:"m5_session_success_rate"`
	M6CostPerSession   float64 `json:"m6_cost_per_session"`
	M7FailureRateDelta float64 `json:"m7_failure_rate_delta"`
	M8FallbackRate     float64 `json:"m8_fallback_rate"`
	M9MedianLatencyMs  float64 `json:"m9_median_latency_ms"`
	M10ToolCallSuccess float64 `json:"m10_tool_call_success_rate"`
}

// NoDataVerdict builds the "no data" verdict for a run with zero usable
// agent trace data. Manual/test payloads present in the window are counted
// separately and do not count as worker-benefit evidence.
func NoDataVerdict(proposalID string, from, to time.Time, obs []Observation, fetchErr error) Verdict {
	v := Verdict{
		Verdict:     "no_data",
		ProposalID:  proposalID,
		GeneratedAt: time.Now().UTC(),
		Reason:      "no agent trace data available in Langfuse window",
	}
	v.Window.From = from
	v.Window.To = to
	v.Window.Observations = len(obs)
	v.Window.HasTraceData = false

	// Classify observations: anything not a manually-created test span is a
	// candidate agent trace. Today every observation is the known manual test
	// payload (name "v1-traces-path-test", no model attribution), so agent
	// traces = 0. The heuristic stays conservative: a span counts as a real
	// agent trace only if it carries a model or usage; test payloads have
	// neither.
	for _, o := range obs {
		if o.Model != nil || o.TotalTokens > 0 {
			v.Window.AgentTraces++
		} else {
			v.Window.ManualSpans++
		}
	}

	if v.Window.AgentTraces > 0 {
		v.Verdict = "pending"
		v.Window.HasTraceData = true
		v.Reason = fmt.Sprintf("%d agent trace(s) present — metric computation not yet implemented (Phase 1)", v.Window.AgentTraces)
	}
	if fetchErr != nil {
		v.Reason = "langfuse API unreachable/error; treated as no data: " + fetchErr.Error()
	}
	return v
}

// OutputDir returns the data/benefit directory under the nightforge repo root.
// Root is inferred from the executable path's ancestors; overridable via
// NIGHTFORGE_ROOT env for tests/dev.
func OutputDir() string {
	if root := os.Getenv("NIGHTFORGE_ROOT"); root != "" {
		return filepath.Join(root, "data", "benefit")
	}
	// Fall back to the conventional nightforge location.
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Github", "nightforge", "data", "benefit")
}

// WriteVerdict writes the verdict as JSON to data/benefit/ and returns the
// path. If proposalID is empty, the file is named daily.json.
func WriteVerdict(v Verdict) (string, error) {
	dir := OutputDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("mkdir benefit dir: %w", err)
	}
	name := "daily.json"
	if id := strings.TrimSpace(v.ProposalID); id != "" {
		name = id + ".json"
	}
	path := filepath.Join(dir, name)

	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal verdict: %w", err)
	}
	b = append(b, '\n')
	if err := os.WriteFile(path, b, 0o644); err != nil {
		return "", fmt.Errorf("write verdict: %w", err)
	}
	return path, nil
}
