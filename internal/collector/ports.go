package collector

import (
	"os/exec"
	"sort"
	"strconv"
	"strings"

	"github.com/ForeverLX/nightforge/internal/collector/model"
)

// PortServices maps known TCP ports to human-readable service names.
var PortServices = map[int]string{
	22:     "SSH",
	53:     "DNS",
	80:     "HTTP",
	443:    "HTTPS",
	5432:   "PostgreSQL",
	5672:   "RabbitMQ",
	6600:   "MPD",
	6444:   "K8s",
	7443:   "Mythic",
	7444:   "Ghostwriter",
	8065:   "Mattermost",
	8080:   "HTTP-alt",
	8585:   "MemLawb",
	8787:   "Headroom",
	8788:   "Headroom-local",
	8888:   "Hexstrike",
	9119:   "Hermes",
	9191:   "Dashboard",
	18234:  "Bonsai",
	43439:  "OpenCode",
	47657:  "Hunk",
}

// GetPorts runs lsof -iTCP -sTCP:LISTEN -P -n and parses listening ports.
// Falls back to empty slice on error.
func GetPorts() []model.Port {
	cmd := exec.Command("lsof", "-iTCP", "-sTCP:LISTEN", "-P", "-n")
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	lines := strings.Split(string(out), "\n")
	var ports []model.Port
	seen := make(map[int]bool)

	// Skip header line (first line)
	for _, line := range lines[1:] {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) < 10 {
			continue
		}

		// lsof output: COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME (LISTEN)
		// NAME is second-to-last field: "127.0.0.1:8585" or "*:10250"
		cmdName := parts[0]
		addr := parts[len(parts)-2]

		// Extract port from addr: split on last colon
		colonIdx := strings.LastIndex(addr, ":")
		if colonIdx < 0 {
			continue
		}
		portStr := addr[colonIdx+1:]
		// Strip trailing bracket from IPv6
		portStr = strings.TrimRight(portStr, "]")

		portNum, err := strconv.Atoi(portStr)
		if err != nil {
			continue
		}

		if seen[portNum] {
			continue
		}
		seen[portNum] = true

		svc := cmdName
		if name, ok := PortServices[portNum]; ok {
			svc = name
		}

		ports = append(ports, model.Port{
			Port:    portStr,
			Process: cmdName,
			Service: svc,
		})
	}

	sort.Slice(ports, func(i, j int) bool {
		pi, _ := strconv.Atoi(ports[i].Port)
		pj, _ := strconv.Atoi(ports[j].Port)
		return pi < pj
	})

	return ports
}
