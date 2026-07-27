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
