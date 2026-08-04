package collector

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"

	"github.com/ForeverLX/nightforge/internal/collector/model"
)

// logsDir is the directory containing automation log files.
var logsDir = func() string {
	return filepath.Join(os.Getenv("HOME"), "local-dashboard", "logs")
}()

// LogsDir returns the configured logs directory path.
func LogsDir() string { return logsDir }

// GetLogFiles returns all .log files found in the logs directory.
func GetLogFiles() ([]model.LogFile, error) {
	entries, err := os.ReadDir(logsDir)
	if err != nil {
		return nil, err
	}

	var files []model.LogFile
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".log") {
			continue
		}
		files = append(files, model.LogFile{
			Name: e.Name(),
			Path: filepath.Join(logsDir, e.Name()),
		})
	}
	return files, nil
}

// GetLogLines reads the last maxLines lines from filePath.
// Returns a string slice with the lines (newest last).
func GetLogLines(filePath string, maxLines int) ([]string, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	// Read all lines
	var lines []string
	scanner := bufio.NewScanner(f)
	// Increase buffer for long lines
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	if len(lines) <= maxLines {
		return lines, nil
	}
	return lines[len(lines)-maxLines:], nil
}
