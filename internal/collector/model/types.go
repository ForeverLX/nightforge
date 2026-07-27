// Package model defines shared types for the nightforge collector.
package model

// Health holds system health data parsed from system-health.log.
type Health struct {
	DiskRootPct  int       `json:"disk_root_pct"`
	DiskRootUsed string    `json:"disk_root_used"`
	DiskRootFree string    `json:"disk_root_free"`
	DiskHomePct  int       `json:"disk_home_pct"`
	DiskHomeUsed string    `json:"disk_home_used"`
	DiskHomeFree string    `json:"disk_home_free"`
	MemPct       int       `json:"mem_pct"`
	MemTotal     string    `json:"mem_total"`
	MemUsed      string    `json:"mem_used"`
	Load         []float64 `json:"load"`
	GPUMem       int       `json:"gpu_mem"`
	GPUTotal     int       `json:"gpu_total"`
}

// Port represents a listening TCP port.
type Port struct {
	Port    string `json:"port"`
	Process string `json:"process"`
	Service string `json:"service"`
}

// Service represents a known service and its runtime status.
type Service struct {
	Name   string `json:"name"`
	Port   int    `json:"port"`
	Status string `json:"status"` // "UP" or "DOWN"
}

// Task represents an automation task's last run status.
type Task struct {
	Name    string `json:"name"`
	LastRun string `json:"last_run"`
	Status  string `json:"status"` // "ok", "action needed", "has errors", "unknown"
}

// LogFile is a discovered log file entry.
type LogFile struct {
	Name string `json:"name"`
	Path string `json:"path"`
}

// Layer represents one of the 10-layer architecture tiers.
type Layer struct {
	ID          int    `json:"id"`
	Name        string `json:"name"`
	Status      string `json:"status"` // "implemented", "available", "not_implemented"
	Description string `json:"description"`
	LastRun     string `json:"last_run"`
}

// FailureReport is a parsed L4 failure mining report.
type FailureReport struct {
	ID       string `json:"id"`
	Category string `json:"category"`
	Count    int    `json:"count"`
	Summary  string `json:"summary"`
}

// Proposal is a parsed L5 proposal engine entry.
type Proposal struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	ImpactScore int    `json:"impact_score"`
	EffortScore int    `json:"effort_score"`
	Status      string `json:"status"`
}

// GateResult is a parsed L6 validation gate check result.
type GateResult struct {
	Name     string  `json:"name"`
	Status   string  `json:"status"` // "PASS", "FAIL", "SKIP"
	Duration float64 `json:"duration"`
	Error    string  `json:"error,omitempty"`
}

// Snapshot is a parsed L7 config snapshot entry.
type Snapshot struct {
	ID        string `json:"id"`
	Timestamp string `json:"timestamp"`
	Path      string `json:"path"`
	Size      int64  `json:"size"`
}

// UsageRecord tracks API usage for a provider/model combination over a period.
type UsageRecord struct {
	Provider     string  `json:"provider"`
	Model        string  `json:"model"`
	TokensIn     int64   `json:"tokens_in"`
	TokensOut    int64   `json:"tokens_out"`
	Cost         float64 `json:"cost"`
	Period       string  `json:"period"` // "day", "week", or "month"
	RequestCount int64   `json:"request_count"`
}

// HistoryPoint is a time-series health snapshot stored in history.
type HistoryPoint struct {
	Timestamp string `json:"timestamp"`
	Health    Health `json:"health"`
}

// AlertSeverity indicates how critical an alert is.
type AlertSeverity string

const (
	AlertWarn  AlertSeverity = "warning"
	AlertCrit  AlertSeverity = "critical"
	AlertInfo  AlertSeverity = "info"
)

// ActiveAlert represents a currently-triggered alert condition.
type ActiveAlert struct {
	ID        string        `json:"id"`
	Severity  AlertSeverity `json:"severity"`
	Message   string        `json:"message"`
	Detail    string        `json:"detail,omitempty"`
	Triggered string        `json:"triggered"`
}

// AlertThreshold defines a named threshold configuration.
type AlertThreshold struct {
	Name     string  `json:"name"`
	Metric   string  `json:"metric"`
	Operator string  `json:"operator"` // "gt", "lt", "eq"
	Value    float64 `json:"value"`
	Severity AlertSeverity `json:"severity"`
	Message  string  `json:"message"`
}
