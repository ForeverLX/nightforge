package l9benefit

import (
	"testing"
	"time"
)

func TestNoDataVerdict_EmptyWindow(t *testing.T) {
	from := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 8, 8, 0, 0, 0, 0, time.UTC)
	v := NoDataVerdict("", from, to, nil, nil)

	if v.Verdict != "no_data" {
		t.Fatalf("expected no_data, got %q", v.Verdict)
	}
	if v.Window.Observations != 0 || v.Window.AgentTraces != 0 {
		t.Fatalf("expected zero observations/traces, got %d/%d", v.Window.Observations, v.Window.AgentTraces)
	}
	if v.Window.HasTraceData {
		t.Fatal("expected HasTraceData=false")
	}
}

func TestNoDataVerdict_ManualSpansNotTraces(t *testing.T) {
	// A manual test span (no model, no usage) must NOT count as an agent trace.
	obs := []Observation{
		{ID: "x1", Name: "v1-traces-path-test", Type: "SPAN", StartTime: "2026-08-08T19:14:54Z"},
	}
	v := NoDataVerdict("prop-2026-08-08-001", time.Now().AddDate(0, 0, -7), time.Now(), obs, nil)

	if v.Verdict != "no_data" {
		t.Fatalf("expected no_data (manual span only), got %q", v.Verdict)
	}
	if v.Window.AgentTraces != 0 {
		t.Fatalf("manual span misclassified as agent trace: AgentTraces=%d", v.Window.AgentTraces)
	}
	if v.Window.ManualSpans != 1 {
		t.Fatalf("expected 1 manual span, got %d", v.Window.ManualSpans)
	}
	if v.ProposalID != "prop-2026-08-08-001" {
		t.Fatalf("proposal id not propagated: %q", v.ProposalID)
	}
}

func TestNoDataVerdict_AgentTracesFuture(t *testing.T) {
	// Once a real span with a model or usage appears, verdict flips to
	// "pending" (metric computation is Phase 1), not no_data.
	model := "deepseek-v4-flash"
	obs := []Observation{
		{ID: "a1", Name: "agent-call", Type: "GENERATION", Model: &model, TotalTokens: 1000},
	}
	v := NoDataVerdict("", time.Now().AddDate(0, 0, -7), time.Now(), obs, nil)

	if v.Verdict != "pending" {
		t.Fatalf("expected pending when agent traces exist, got %q", v.Verdict)
	}
	if v.Window.AgentTraces != 1 {
		t.Fatalf("expected 1 agent trace, got %d", v.Window.AgentTraces)
	}
	if !v.Window.HasTraceData {
		t.Fatal("expected HasTraceData=true")
	}
}

func TestNoDataVerdict_FetchError(t *testing.T) {
	from := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)
	to := time.Date(2026, 8, 8, 0, 0, 0, 0, time.UTC)
	v := NoDataVerdict("", from, to, nil, errTest)

	if v.Verdict != "no_data" {
		t.Fatalf("expected no_data on fetch error, got %q", v.Verdict)
	}
	if v.Reason == "" {
		t.Fatal("expected fetch error in reason")
	}
}

var errTest = &syntheticErr{msg: "langfuse API HTTP 500"}

type syntheticErr struct{ msg string }

func (e *syntheticErr) Error() string { return e.msg }
