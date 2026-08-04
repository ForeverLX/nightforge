package collector

import "fmt"

type AnalysisItem struct {
	Source string `json:"source"`
	Text   string `json:"text"`
}

// GetAnalysis returns a list of analysis items derived from collector data.
// Used by the analysis endpoint and SSE hub.
func GetAnalysis() []AnalysisItem {
	var items []AnalysisItem

	health := GetHealth()
	services := GetServices()
	ports := GetPorts()

	// Service health
	up, down := 0, 0
	for _, s := range services {
		if s.Status == "UP" {
			up++
		} else {
			down++
		}
	}

	items = append(items, AnalysisItem{
		Source: "Services",
		Text:   fmt.Sprintf("%d services up, %d services down across %d monitored ports", up, down, len(ports)),
	})

	// Disk health
	if health.DiskRootPct > 80 {
		items = append(items, AnalysisItem{
			Source: "Disk",
			Text:   fmt.Sprintf("Root disk at %d%% capacity (%s used / %s free). Consider cleaning.", health.DiskRootPct, health.DiskRootUsed, health.DiskRootFree),
		})
	}

	// GPU
	if health.GPUTotal > 0 {
		pct := float64(health.GPUMem) / float64(health.GPUTotal) * 100
		items = append(items, AnalysisItem{
			Source: "GPU",
			Text:   fmt.Sprintf("GPU memory: %d / %d MB (%.0f%%)", health.GPUMem, health.GPUTotal, pct),
		})
	}

	// Load
	if len(health.Load) >= 3 {
		items = append(items, AnalysisItem{
			Source: "Load",
			Text:   fmt.Sprintf("CPU load: %.2f / %.2f / %.2f (1/5/15 min)", health.Load[0], health.Load[1], health.Load[2]),
		})
	}

	return items
}
