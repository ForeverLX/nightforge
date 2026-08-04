// Package nfutil — shared helpers for the NightForge CUE toolchain.
//
// The CUE migration toolchain (cmd/cue-to-kdl, cmd/fidelity-check,
// cmd/cue-validate, cmd/niri-staging-validate) all need to (a) locate the
// repository root and (b) export the CUE config to JSON. That shared
// plumbing lives here so each tool stays a thin main package.
package nfutil

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// Config mirrors the JSON export of cue/nightforge.cue (package niri, top
// field "config"). Field names map 1:1 to the CUE schema (schema.cue).
type Config struct {
	SpawnAtStartup []Spawn `json:"spawnAtStartup"`
	Binds          []Bind  `json:"binds"`
	WindowRules    []Rule  `json:"windowRules"`
}

type Spawn struct {
	Argv []string `json:"argv"`
}

type Action struct {
	Kind string   `json:"kind"`
	Argv []string `json:"argv"`
	Name string   `json:"name"`
	Arg  *string  `json:"arg"`
}

type Bind struct {
	Combo              string  `json:"combo"`
	Action             Action  `json:"action"`
	AllowWhenLocked    *bool   `json:"allowWhenLocked"`
	Repeat             *bool   `json:"repeat"`
	HotkeyOverlayTitle *string `json:"hotkeyOverlayTitle"`
}

// Width is a CUE #Proportion | #Fixed union. Exactly one pointer is set.
// Numbers are json.Number to preserve the exported int/float form
// (CUE emits "0.0" for opacity 0.0 but "8" for a radius of 8; Python's
// json.loads made the same int/float distinction and the renderer keeps it).
type Width struct {
	Proportion *json.Number `json:"proportion"`
	Fixed      *json.Number `json:"fixed"`
}

type Rule struct {
	AppID                *string     `json:"appId"`
	Title                *string     `json:"title"`
	Opacity              *json.Number `json:"opacity"`
	OpenFloating         *bool       `json:"openFloating"`
	OpenFullscreen       *bool       `json:"openFullscreen"`
	ClipToGeometry       *bool       `json:"clipToGeometry"`
	GeometryCornerRadius *json.Number `json:"geometryCornerRadius"`
	MaxWidth             *json.Number `json:"maxWidth"`
	MaxHeight            *json.Number `json:"maxHeight"`
	BlockOutFrom         *string     `json:"blockOutFrom"`
	DefaultColumnWidth   *Width      `json:"defaultColumnWidth"`
	DefaultWindowHeight  *Width      `json:"defaultWindowHeight"`
}

// RepoRoot locates the repository root (the directory containing
// cue/nightforge.cue) by walking up from the working directory, then from
// the executable's directory. Tools are documented to run from the repo
// root; the executable fallback covers build/bin invocations.
func RepoRoot() (string, error) {
	var starts []string
	if cwd, err := os.Getwd(); err == nil {
		starts = append(starts, cwd)
	}
	if exe, err := os.Executable(); err == nil {
		starts = append(starts, filepath.Dir(exe))
	}
	seen := map[string]bool{}
	for _, start := range starts {
		for cur := start; ; cur = filepath.Dir(cur) {
			if seen[cur] {
				break
			}
			seen[cur] = true
			if _, err := os.Stat(filepath.Join(cur, "cue", "nightforge.cue")); err == nil {
				return cur, nil
			}
			parent := filepath.Dir(cur)
			if parent == cur {
				break
			}
		}
	}
	return "", fmt.Errorf("cannot locate repo root (cue/nightforge.cue not found from %v)", starts)
}

// ExportConfig runs `cue export . --out json` in <root>/cue and unmarshals
// the exported config. A failing cue export is an error (exit 1 upstream).
func ExportConfig(root string) (Config, error) {
	cmd := exec.Command("cue", "export", ".", "--out", "json")
	cmd.Dir = filepath.Join(root, "cue")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return Config{}, fmt.Errorf("cue export failed: %w\n%s", err, out)
	}
	var doc struct {
		Config Config `json:"config"`
	}
	dec := json.NewDecoder(bytes.NewReader(out))
	dec.UseNumber()
	if err := dec.Decode(&doc); err != nil {
		return Config{}, fmt.Errorf("parse cue export: %w", err)
	}
	return doc.Config, nil
}
