package collector

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/ForeverLX/nightforge-dashboard/internal/collector/model"
)

// DefaultThresholds defines the built-in alert thresholds.
var DefaultThresholds = []model.AlertThreshold{
	{
		Name:     "disk-root-high",
		Metric:   "disk_root_pct",
		Operator: "gt",
		Value:    90,
		Severity: model.AlertCrit,
		Message:  "Root disk usage exceeds 90%%",
	},
	{
		Name:     "disk-home-high",
		Metric:   "disk_home_pct",
		Operator: "gt",
		Value:    90,
		Severity: model.AlertCrit,
		Message:  "Home disk usage exceeds 90%%",
	},
	{
		Name:     "disk-root-warn",
		Metric:   "disk_root_pct",
		Operator: "gt",
		Value:    80,
		Severity: model.AlertWarn,
		Message:  "Root disk usage exceeds 80%%",
	},
	{
		Name:     "disk-home-warn",
		Metric:   "disk_home_pct",
		Operator: "gt",
		Value:    80,
		Severity: model.AlertWarn,
		Message:  "Home disk usage exceeds 80%%",
	},
	{
		Name:     "memory-high",
		Metric:   "mem_pct",
		Operator: "gt",
		Value:    90,
		Severity: model.AlertCrit,
		Message:  "Memory usage exceeds 90%%",
	},
	{
		Name:     "memory-warn",
		Metric:   "mem_pct",
		Operator: "gt",
		Value:    80,
		Severity: model.AlertWarn,
		Message:  "Memory usage exceeds 80%%",
	},
}

// GetAlerts evaluates current state against thresholds and returns active alerts.
func GetAlerts(health model.Health, services []model.Service) []model.ActiveAlert {
	var alerts []model.ActiveAlert
	now := time.Now().UTC().Format(time.RFC3339)

	for _, t := range DefaultThresholds {
		val := getMetricValue(health, t.Metric)
		if triggered := compareValues(val, t.Value, t.Operator); triggered {
			alerts = append(alerts, model.ActiveAlert{
				ID:        fmt.Sprintf("%s-%d", t.Name, time.Now().Unix()),
				Severity:  t.Severity,
				Message:   t.Message,
				Detail:    fmt.Sprintf("%s = %.0f (threshold: %s %.0f)", t.Metric, val, t.Operator, t.Value),
				Triggered: now,
			})
		}
	}

	// Check for down services (critical if any known service is down)
	var downServices []string
	for _, svc := range services {
		if svc.Status == "DOWN" {
			downServices = append(downServices, fmt.Sprintf("%s (port %d)", svc.Name, svc.Port))
		}
	}
	if len(downServices) > 0 {
		alerts = append(alerts, model.ActiveAlert{
			ID:        fmt.Sprintf("service-down-%d", time.Now().Unix()),
			Severity:  model.AlertCrit,
			Message:   fmt.Sprintf("%d service(s) are DOWN", len(downServices)),
			Detail:    strings.Join(downServices, ", "),
			Triggered: now,
		})
	}

	// Check for LLM crash: if Bonsai port is configured but unreachable
	bonsaiHost := os.Getenv("BONSAI_HOST")
	if bonsaiHost == "" {
		bonsaiHost = "http://127.0.0.1:18234"
	}
	// Bonsai check is done via service status already

	return alerts
}

// getMetricValue extracts a float metric value from Health by field name.
func getMetricValue(h model.Health, metric string) float64 {
	switch metric {
	case "disk_root_pct":
		return float64(h.DiskRootPct)
	case "disk_home_pct":
		return float64(h.DiskHomePct)
	case "mem_pct":
		return float64(h.MemPct)
	case "gpu_mem":
		return float64(h.GPUMem)
	case "gpu_total":
		return float64(h.GPUTotal)
	case "load_1":
		if len(h.Load) > 0 {
			return h.Load[0]
		}
	case "load_5":
		if len(h.Load) > 1 {
			return h.Load[1]
		}
	case "load_15":
		if len(h.Load) > 2 {
			return h.Load[2]
		}
	}
	return 0
}

// compareValues checks if actual meets the threshold condition.
func compareValues(actual, threshold float64, operator string) bool {
	switch operator {
	case "gt":
		return actual > threshold
	case "lt":
		return actual < threshold
	case "gte":
		return actual >= threshold
	case "lte":
		return actual <= threshold
	case "eq":
		return actual == threshold
	}
	return false
}

// IsServiceDown checks if a specific service by name is down in the given list.
func IsServiceDown(services []model.Service, name string) bool {
	for _, s := range services {
		if s.Name == name && s.Status == "DOWN" {
			return true
		}
	}
	return false
}

// FormatBytes parses a size string like "45G", "16Gi", "8192" and returns the
// raw numeric value for threshold comparison.
func FormatBytes(s string) (int, error) {
	s = strings.TrimSpace(s)
	s = strings.TrimSuffix(s, "i")
	s = strings.TrimSuffix(s, "B")
	s = strings.TrimSuffix(s, "b")
	if s == "" {
		return 0, fmt.Errorf("empty string")
	}

	multiplier := 1
	switch {
	case strings.HasSuffix(s, "T"):
		multiplier = 1024 * 1024 * 1024 * 1024
	case strings.HasSuffix(s, "G"):
		multiplier = 1024 * 1024 * 1024
	case strings.HasSuffix(s, "M"):
		multiplier = 1024 * 1024
	case strings.HasSuffix(s, "K"):
		multiplier = 1024
	}

	if multiplier > 1 {
		s = s[:len(s)-1]
	}

	v, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("parse %q: %w", s, err)
	}
	return v * multiplier, nil
}
