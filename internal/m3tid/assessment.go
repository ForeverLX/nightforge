// Package m3tid encodes the MITRE Center for Threat-Informed Defense (CTID)
// M3TID scoring methodology ("Measure, Maximize, and Mature Threat-Informed
// Defense", v1.0.0, document CT0105) and the current CR1MS0N stack assessment.
//
// Methodology (from the official INFORM.xlsx scoring spreadsheet):
//   - Three dimensions: CTI, DM, T&E — each with five components.
//   - Each component has five maturity levels; points are cumulative:
//     level 1 or 2 satisfied earns 1 point, level 3 or 4 earns 2 points.
//     Component score ranges 0..6.
//   - Dimension score = mean of its component scores (0..6).
//   - Overall = weighted sum (DM 0.5, CTI 0.3, T&E 0.2) normalized by the
//     weighted maximum (6), i.e. a 0..1 maturity fraction.
package m3tid

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
)

// Level points per the official spreadsheet: L1=1, L2=1, L3=2, L4=2.
// Level 5 is documented as aspirational future state and carries no points.
var levelPoints = map[int]float64{1: 1, 2: 1, 3: 2, 4: 2}

// ComponentMax is the maximum attainable component score (1+1+2+2).
const ComponentMax = 6.0

// Component is one of the fifteen M3TID components.
type Component struct {
	ID        string   `json:"id"`
	Name      string   `json:"name"`
	LevelsMet []int    `json:"levels_met"` // maturity levels satisfied, ascending
	Evidence  []string `json:"evidence"`   // repo-relative evidence paths
	Note      string   `json:"note,omitempty"`
}

// Score returns the cumulative points for the satisfied levels.
func (c Component) Score() float64 {
	var s float64
	for _, lvl := range c.LevelsMet {
		s += levelPoints[lvl]
	}
	return s
}

// Dimension is CTI, DM, or T&E. Weight is the official dimension weight.
type Dimension struct {
	ID         string      `json:"id"`
	Name       string      `json:"name"`
	Weight     float64     `json:"weight"`
	Components []Component `json:"components"`
}

// Score returns the dimension score: the mean of its component scores.
func (d Dimension) Score() float64 {
	if len(d.Components) == 0 {
		return 0
	}
	var sum float64
	for _, c := range d.Components {
		sum += c.Score()
	}
	return sum / float64(len(d.Components))
}

// Overall holds the weighted overall maturity result.
type Overall struct {
	WeightedScore float64 `json:"weighted_score"` // 0..6 scale
	Max           float64 `json:"max"`
	Percent       float64 `json:"percent"` // 0..100
}

// Assessment is the full machine-readable result written to data/tid/m3tid.json.
type Assessment struct {
	Framework        string      `json:"framework"`
	FrameworkVersion string      `json:"framework_version"`
	FrameworkRef     string      `json:"framework_ref"`
	AssessedDate     string      `json:"assessed_date"`
	AssessedBy       string      `json:"assessed_by"`
	Scope            []string    `json:"scope"`
	Overall          Overall     `json:"overall"`
	Dimensions       []Dimension `json:"dimensions"`
	Notes            []string    `json:"notes"`
}

// ComputeOverall applies the official weighting formula:
//
//	overall = (w_CTI*CTI + w_DM*DM + w_TE*TE) / (w_CTI + w_DM + w_TE) / ComponentMax
//
// with weights DM=0.5, CTI=0.3, T&E=0.2. Since every dimension shares the
// 0..6 scale the weighted maximum is 6.
func ComputeOverall(dims []Dimension) Overall {
	var weighted float64
	var weightSum float64
	for _, d := range dims {
		weighted += d.Weight * d.Score()
		weightSum += d.Weight
	}
	weighted /= weightSum
	return Overall{
		WeightedScore: round1(weighted),
		Max:           ComponentMax,
		Percent:       round1(weighted / ComponentMax * 100),
	}
}

// OutputDir returns the data/tid directory under the nightforge repo root.
// Root is overridable via NIGHTFORGE_ROOT env for tests/dev.
func OutputDir() string {
	if root := os.Getenv("NIGHTFORGE_ROOT"); root != "" {
		return filepath.Join(root, "data", "tid")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Github", "nightforge", "data", "tid")
}

// Write writes the assessment as JSON to data/tid/m3tid.json and returns the
// path. The file is the harness's source of truth for the TID tab.
func Write(a Assessment) (string, error) {
	dir := OutputDir()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", fmt.Errorf("mkdir tid dir: %w", err)
	}
	path := filepath.Join(dir, "m3tid.json")
	b, err := json.MarshalIndent(a, "", "  ")
	if err != nil {
		return "", fmt.Errorf("marshal assessment: %w", err)
	}
	b = append(b, '\n')
	if err := os.WriteFile(path, b, 0o644); err != nil {
		return "", fmt.Errorf("write assessment: %w", err)
	}
	return path, nil
}

func round1(v float64) float64 {
	return float64(int(v*10+0.5)) / 10
}

// SortedLevels returns the satisfied levels in ascending order (used by the
// generator to keep the JSON canonical).
func SortedLevels(levels []int) []int {
	out := append([]int(nil), levels...)
	sort.Ints(out)
	return out
}
