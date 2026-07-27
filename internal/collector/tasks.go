package collector

import (
	"bufio"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/ForeverLX/nightforge-dashboard/internal/collector/model"
)

// taskLogs maps task display names to their log files.
var taskLogs = []struct {
	Name, File string
}{
	{Name: "ext-update-monitor", File: "ext-update.log"},
	{Name: "system-health", File: "system-health.log"},
	{Name: "file-org", File: "file-org.log"},
	{Name: "port-monitor", File: "port-monitor.log"},
}

// timestampRE matches [YYYY-MM-DD HH:MM:SS] patterns.
var timestampRE = regexp.MustCompile(`\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]`)

// GetTasks reads each log file and determines last run time and status.
// Status is determined by scanning the last portion of the log for indicators:
//
//	"ok" — no errors, task completed normally
//	"action needed" — warnings or updates available
//	"has errors" — error lines found
//	"unknown" — couldn't determine
func GetTasks() []model.Task {
	var tasks []model.Task

	for _, tl := range taskLogs {
		path := filepath.Join(logsDir, tl.File)
		task := model.Task{
			Name:    tl.Name,
			LastRun: "never",
			Status:  "unknown",
		}

		f, err := os.Open(path)
		if err != nil {
			tasks = append(tasks, task)
			continue
		}

		// Read all lines into memory (log files are small)
		var lines []string
		scanner := bufio.NewScanner(f)
		scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
		for scanner.Scan() {
			lines = append(lines, scanner.Text())
		}
		f.Close()

		if len(lines) == 0 {
			tasks = append(tasks, task)
			continue
		}

		// Find last completion timestamp
		for i := len(lines) - 1; i >= 0; i-- {
			line := strings.TrimSpace(lines[i])
			if strings.Contains(line, "— Complete") {
				task.LastRun = line
				break
			}
		}

		// Determine status from last 50 lines
		tailStart := 0
		if len(lines) > 50 {
			tailStart = len(lines) - 50
		}

		hasError := false
		hasWarning := false
		allOK := false

		for _, line := range lines[tailStart:] {
			trimmed := strings.TrimSpace(line)
			if strings.Contains(trimmed, "Error") ||
				strings.Contains(trimmed, "FAILED") ||
				strings.Contains(trimmed, "error") {
				hasError = true
			}
			if strings.Contains(trimmed, "⚠") ||
				strings.Contains(trimmed, "Updates available") ||
				strings.Contains(trimmed, "outdated") {
				hasWarning = true
			}
			if strings.Contains(trimmed, "up to date") ||
				strings.Contains(trimmed, "No port changes") {
				allOK = true
			}
		}

		switch {
		case hasError:
			task.Status = "has errors"
		case hasWarning:
			task.Status = "action needed"
		case allOK:
			task.Status = "ok"
		default:
			task.Status = "unknown"
		}

		tasks = append(tasks, task)
	}

	return tasks
}
