package collector

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// HealthSnapshot represents a single point-in-time system health measurement.
type HealthSnapshot struct {
	Timestamp string     `json:"timestamp"`
	Health    HealthData `json:"health"`
}

// HealthData contains system metrics.
type HealthData struct {
	DiskRootPct  int        `json:"disk_root_pct"`
	DiskRootUsed string     `json:"disk_root_used"`
	DiskRootFree string     `json:"disk_root_free"`
	DiskHomePct  int        `json:"disk_home_pct"`
	DiskHomeUsed string     `json:"disk_home_used"`
	DiskHomeFree string     `json:"disk_home_free"`
	MemPct       int        `json:"mem_pct"`
	MemTotal     string     `json:"mem_total"`
	MemUsed      string     `json:"mem_used"`
	Load         [3]float64 `json:"load"`
	GPUMem       int        `json:"gpu_mem"`
	GPUTotal     int        `json:"gpu_total"`
}

var (
	mu      sync.RWMutex
	history []HealthSnapshot
	dataDir string
)

// Init sets up the collector and starts the 5-minute ticker.
func Init(dataDirectory string) {
	dataDir = dataDirectory
	loadHistory()
	collect()
	go tick()
}

func tick() {
	for {
		time.Sleep(5 * time.Minute)
		collect()
	}
}

// GetHealthHistory returns the latest snapshot and recent history.
func GetHealthHistory() (HealthSnapshot, []HealthSnapshot) {
	mu.RLock()
	defer mu.RUnlock()
	if len(history) == 0 {
		return HealthSnapshot{}, nil
	}
	return history[len(history)-1], history
}

// DailySummary holds min/max/avg stats over the current 24h history.
type DailySummary struct {
	Samples  int       `json:"samples"`
	DiskRoot AvgMinMax `json:"disk_root"`
	DiskHome AvgMinMax `json:"disk_home"`
	MemPct   AvgMinMax `json:"mem_pct"`
	GPUMemMB AvgMinMax `json:"gpu_mem_mb"`
	Load1m   AvgMinMax `json:"load_1m"`
}

// AvgMinMax holds average, minimum, and maximum values.
type AvgMinMax struct {
	Avg float64 `json:"avg"`
	Min float64 `json:"min"`
	Max float64 `json:"max"`
}

// GetDailySummary computes min/max/avg over the current in-memory history.
func GetDailySummary() DailySummary {
	mu.RLock()
	defer mu.RUnlock()

	if len(history) == 0 {
		return DailySummary{}
	}

	diskRoot := AvgMinMax{Min: 100, Max: 0}
	diskHome := AvgMinMax{Min: 100, Max: 0}
	mem := AvgMinMax{Min: 100, Max: 0}
	gpu := AvgMinMax{Min: 1 << 30, Max: 0}
	load1m := AvgMinMax{Min: 1e9, Max: 0}

	for _, h := range history {
		d := h.Health
		if v := float64(d.DiskRootPct); v < diskRoot.Min {
			diskRoot.Min = v
		}
		if v := float64(d.DiskRootPct); v > diskRoot.Max {
			diskRoot.Max = v
		}
		diskRoot.Avg += float64(d.DiskRootPct)

		if v := float64(d.DiskHomePct); v < diskHome.Min {
			diskHome.Min = v
		}
		if v := float64(d.DiskHomePct); v > diskHome.Max {
			diskHome.Max = v
		}
		diskHome.Avg += float64(d.DiskHomePct)

		if v := float64(d.MemPct); v < mem.Min {
			mem.Min = v
		}
		if v := float64(d.MemPct); v > mem.Max {
			mem.Max = v
		}
		mem.Avg += float64(d.MemPct)

		if v := float64(d.GPUMem); v < gpu.Min {
			gpu.Min = v
		}
		if v := float64(d.GPUMem); v > gpu.Max {
			gpu.Max = v
		}
		gpu.Avg += float64(d.GPUMem)

		if v := d.Load[0]; v < load1m.Min {
			load1m.Min = v
		}
		if v := d.Load[0]; v > load1m.Max {
			load1m.Max = v
		}
		load1m.Avg += d.Load[0]
	}

	n := float64(len(history))
	if n > 0 {
		diskRoot.Avg /= n
		diskHome.Avg /= n
		mem.Avg /= n
		gpu.Avg /= n
		load1m.Avg /= n
	}

	return DailySummary{
		Samples:  len(history),
		DiskRoot: diskRoot,
		DiskHome: diskHome,
		MemPct:   mem,
		GPUMemMB: gpu,
		Load1m:   load1m,
	}
}

// --- collection ---

func collect() {
	h := collectHealthData()
	now := time.Now().UTC()
	snapshot := HealthSnapshot{
		Timestamp: now.Format(time.RFC3339),
		Health:    h,
	}

	mu.Lock()
	history = append(history, snapshot)
	if len(history) > 288 {
		history = history[len(history)-288:]
	}
	mu.Unlock()

	appendToJSONL(snapshot)
}

func collectHealthData() HealthData {
	return HealthData{
		DiskRootPct:  getDiskUsage("/"),
		DiskRootUsed: getDiskUsed("/"),
		DiskRootFree: getDiskFree("/"),
		DiskHomePct:  getDiskUsage("/home"),
		DiskHomeUsed: getDiskUsed("/home"),
		DiskHomeFree: getDiskFree("/home"),
		MemPct:       getMemPercent(),
		MemTotal:     getMemTotal(),
		MemUsed:      getMemUsed(),
		Load:         getLoad(),
		GPUMem:       getGPUMemUsed(),
		GPUTotal:     getGPUMemTotal(),
	}
}

// --- disk ---

// execLookPath resolves a binary, preferring absolute paths when PATH is
// unreliable. The harnessd systemd user service runs with a broken PATH
// (literal %E{PATH} in Environment=), so exec.LookPath alone is not enough.
func execLookPath(bin string) string {
	if p, err := exec.LookPath(bin); err == nil {
		return p
	}
	for _, p := range []string{"/usr/bin/" + bin, "/bin/" + bin, "/usr/local/bin/" + bin} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return bin // surface the original exec error downstream
}

func getDiskUsage(path string) int {
	out, err := exec.Command(execLookPath("df"), "--output=pcent", path).Output()
	if err != nil {
		return 0
	}
	lines := strings.Split(string(out), "\n")
	if len(lines) < 2 {
		return 0
	}
	// df pads the value; TrimSpace before stripping % and parsing.
	v := strings.TrimSpace(strings.TrimSuffix(lines[1], "%"))
	pct, err := strconv.Atoi(v)
	if err != nil {
		return 0
	}
	return pct
}

func getDiskUsed(path string) string {
	out, err := exec.Command(execLookPath("df"), "-h", "--output=used", path).Output()
	if err != nil {
		return "?"
	}
	lines := strings.Split(string(out), "\n")
	if len(lines) < 2 {
		return "?"
	}
	return strings.TrimSpace(lines[1])
}

func getDiskFree(path string) string {
	out, err := exec.Command(execLookPath("df"), "-h", "--output=avail", path).Output()
	if err != nil {
		return "?"
	}
	lines := strings.Split(string(out), "\n")
	if len(lines) < 2 {
		return "?"
	}
	return strings.TrimSpace(lines[1])
}

// --- memory ---

func readMemInfo(key string) string {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return "0"
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, key+":") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				return fields[1]
			}
		}
	}
	return "0"
}

func memKB(key string) int {
	v, _ := strconv.Atoi(readMemInfo(key))
	return v
}

func getMemPercent() int {
	total := memKB("MemTotal")
	available := memKB("MemAvailable")
	if total == 0 {
		return 0
	}
	return 100 - (available * 100 / total)
}

func getMemTotal() string {
	t := memKB("MemTotal")
	return fmt.Sprintf("%dG", t/1024/1024)
}

func getMemUsed() string {
	total := memKB("MemTotal")
	avail := memKB("MemAvailable")
	used := (total - avail) / 1024 / 1024
	return fmt.Sprintf("%dG", used)
}

// --- load ---

func getLoad() [3]float64 {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return [3]float64{0, 0, 0}
	}
	fields := strings.Fields(string(data))
	if len(fields) < 3 {
		return [3]float64{0, 0, 0}
	}
	var load [3]float64
	for i := range 3 {
		load[i], _ = strconv.ParseFloat(fields[i], 64)
	}
	return load
}

// --- GPU ---

func nvidiaSMI(query string) string {
	out, err := exec.Command(execLookPath("nvidia-smi"), "--query-gpu="+query, "--format=csv,noheader,nounits").Output()
	if err != nil {
		return "0"
	}
	return strings.TrimSpace(string(out))
}

func getGPUMemUsed() int {
	v, _ := strconv.Atoi(nvidiaSMI("memory.used"))
	return v
}

func getGPUMemTotal() int {
	v, _ := strconv.Atoi(nvidiaSMI("memory.total"))
	return v
}

// --- persistence ---

func appendToJSONL(s HealthSnapshot) {
	if dataDir == "" {
		return
	}
	date := time.Now().UTC().Format("2006-01-02")
	dir := filepath.Join(dataDir, "history")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return
	}
	f, err := os.OpenFile(filepath.Join(dir, "health-"+date+".jsonl"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	json.NewEncoder(f).Encode(s) //nolint:errcheck
}

func loadHistory() {
	if dataDir == "" {
		return
	}
	date := time.Now().UTC().Format("2006-01-02")
	path := filepath.Join(dataDir, "history", "health-"+date+".jsonl")
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	for _, line := range lines {
		var s HealthSnapshot
		if err := json.Unmarshal([]byte(line), &s); err == nil {
			history = append(history, s)
		}
	}
	if len(history) > 288 {
		history = history[len(history)-288:]
	}
}
