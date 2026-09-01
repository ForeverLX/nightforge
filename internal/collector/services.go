package collector

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/CR1MS0N-Operator/nightforge/internal/collector/model"
)

// knownServices is the list of services to monitor.
type serviceDef struct {
	Name string
	Port int
}

var knownServices = []serviceDef{
	{Name: "Bonsai (llama-server)", Port: 18234},
	{Name: "Hermes", Port: 9119},
	{Name: "Hunk", Port: 47657},
	{Name: "OpenCode", Port: 43439},
	{Name: "Headroom (nous)", Port: 8787},
	{Name: "Headroom (local)", Port: 8788},
	{Name: "Hexstrike", Port: 8888},
	{Name: "Mattermost", Port: 8065},
	{Name: "PostgreSQL", Port: 5432},
	{Name: "RabbitMQ", Port: 5672},
	{Name: "MPD", Port: 6600},
	{Name: "SSH", Port: 22},
	{Name: "DNS", Port: 53},
	{Name: "HTTP (nginx)", Port: 80},
}

// GetServices checks each known service port via lsof and returns UP/DOWN status.
// Bonsai gets an extended check: HTTP GET to /v1/models for model load status.
func GetServices() []model.Service {
	var services []model.Service

	// Get all listening ports once for efficiency
	listening := getListeningPorts()

	for _, svc := range knownServices {
		s := model.Service{
			Name:   svc.Name,
			Port:   svc.Port,
			Status: "DOWN",
		}
		if listening[svc.Port] {
			s.Status = "UP"
		}

		// Extended check for Bonsai
		if svc.Port == 18234 && s.Status == "UP" {
			s.Status = checkBonsaiModel()
		}

		services = append(services, s)
	}

	return services
}

// getListeningPorts returns a set of ports currently in LISTEN state.
func getListeningPorts() map[int]bool {
	cmd := exec.Command("lsof", "-iTCP", "-sTCP:LISTEN", "-P", "-n")
	out, err := cmd.Output()
	if err != nil {
		return nil
	}

	ports := make(map[int]bool)
	for _, line := range strings.Split(string(out), "\n") {
		parts := strings.Fields(line)
		if len(parts) < 10 {
			continue
		}
		addr := parts[len(parts)-2]
		colonIdx := strings.LastIndex(addr, ":")
		if colonIdx < 0 {
			continue
		}
		portStr := strings.TrimRight(addr[colonIdx+1:], "]")
		if n, err := strconv.Atoi(portStr); err == nil {
			ports[n] = true
		}
	}
	return ports
}

// checkBonsaiModel checks if Bonsai has a model loaded via its API.
func checkBonsaiModel() string {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("http://127.0.0.1:18234/v1/models")
	if err != nil {
		return fmt.Sprintf("UP\n(API unreachable: %v)", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Sprintf("UP\n(API HTTP %d)", resp.StatusCode)
	}

	var body struct {
		Data []struct {
			ID     string `json:"id"`
			Status struct {
				Value string `json:"value"`
			} `json:"status"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return "UP\n(API response parse error)"
	}

	for _, m := range body.Data {
		if m.Status.Value == "loaded" {
			return fmt.Sprintf("UP\n(%s)", m.ID)
		}
	}
	return "UP\n(no model loaded)"
}
