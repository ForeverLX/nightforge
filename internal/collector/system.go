package collector

import (
	"os"
	"regexp"
	"strconv"

	"github.com/ForeverLX/nightforge/internal/collector/model"
)

// healthLogPath is the path to the system health log file.
var healthLogPath = os.ExpandEnv("$HOME/local-dashboard/logs/system-health.log")

// GetHealth parses system-health.log and returns structured health data.
// Returns zero-value Health if the file is missing or unparseable.
func GetHealth() model.Health {
	h := model.Health{GPUTotal: 8192}

	data, err := os.ReadFile(healthLogPath)
	if err != nil {
		return h
	}
	text := string(data)

	// Disk: captures lines like "45G total, 39G used, 4.1G avail (91%)"
	diskRE := regexp.MustCompile(`(\d+G) total, (\d+G) used, [\d.]+G avail \((\d+)%\)`)
	matches := diskRE.FindAllStringSubmatch(text, -1)
	if len(matches) >= 2 {
		h.DiskRootUsed = matches[0][1]
		h.DiskRootFree = matches[0][1]
		h.DiskRootPct, _ = strconv.Atoi(matches[0][3])
		h.DiskHomeUsed = matches[1][1]
		h.DiskHomeFree = matches[1][1]
		h.DiskHomePct, _ = strconv.Atoi(matches[1][3])
	}

	// Memory: "Mem:        39Gi        16Gi       8.3Gi  …"
	memRE := regexp.MustCompile(`Mem:\s+(\d+)Gi?\s+([\d.]+)Gi?\s+([\d.]+)Gi?`)
	if m := memRE.FindStringSubmatch(text); m != nil {
		total, _ := strconv.ParseFloat(m[1], 64)
		used, _ := strconv.ParseFloat(m[2], 64)
		if total > 0 {
			h.MemPct = int(used/total*100 + 0.5)
		}
		h.MemTotal = m[1] + "G"
		h.MemUsed = m[2] + "G"
	}

	// Load: match line starting with three space-separated float values
	// e.g. "1.91 1.98 1.75 4/2160 873158"
	loadRE := regexp.MustCompile(`(?m)^([\d.]+)\s+([\d.]+)\s+([\d.]+)`)
	if m := loadRE.FindStringSubmatch(text); m != nil {
		a, _ := strconv.ParseFloat(m[1], 64)
		b, _ := strconv.ParseFloat(m[2], 64)
		c, _ := strconv.ParseFloat(m[3], 64)
		h.Load = []float64{a, b, c}
	}

	// GPU: "5988 MiB, 8192 MiB"
	gpuRE := regexp.MustCompile(`(\d+) MiB, (\d+) MiB`)
	if m := gpuRE.FindStringSubmatch(text); m != nil {
		h.GPUMem, _ = strconv.Atoi(m[1])
		h.GPUTotal, _ = strconv.Atoi(m[2])
	}

	return h
}
