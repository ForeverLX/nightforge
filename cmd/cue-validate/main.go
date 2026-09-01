// cue-validate — validate the NightForge CUE config against the schema.
//
// Go port of scripts/cue-validate.sh (S187). Same checks, same output,
// same exit codes; removes the jq dependency:
//
//  1. cue fmt --check — formatting is canonical
//  2. cue vet — data satisfies schema constraints
//  3. structural sanity via cue export (counts printed for the record)
//
// Usage:
//
//	cue-validate
//
// Exit 0 on success, non-zero on any failure.
package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/CR1MS0N-Operator/nightforge/internal/nfutil"
)

var errFmt = errors.New("cue fmt --check failed")

func run() error {
	root, err := nfutil.RepoRoot()
	if err != nil {
		return err
	}
	cueDir := filepath.Join(root, "cue")

	fmt.Println("==> cue fmt --check")
	fmtCmd := exec.Command("cue", "fmt", "--check", ".")
	fmtCmd.Dir = cueDir
	out, err := fmtCmd.CombinedOutput()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR: CUE formatting drift:")
		os.Stderr.Write(out)
		fmt.Fprintln(os.Stderr, "Run: (cd cue && cue fmt .)")
		return errFmt
	}

	fmt.Println("==> cue vet")
	cmd := exec.Command("cue", "vet", ".")
	cmd.Dir = cueDir
	if out, err := cmd.CombinedOutput(); err != nil {
		os.Stderr.Write(out)
		return fmt.Errorf("cue vet failed: %w", err)
	}

	fmt.Println("==> cue export (counts)")
	cfg, err := nfutil.ExportConfig(root)
	if err != nil {
		return err
	}
	fmt.Printf("spawn-at-startup: %d\n", len(cfg.SpawnAtStartup))
	fmt.Printf("binds:            %d\n", len(cfg.Binds))
	fmt.Printf("window-rules:     %d\n", len(cfg.WindowRules))

	fmt.Println("OK: CUE schemas validate (nightforge.niri).")
	return nil
}

func main() {
	if err := run(); err != nil {
		if !errors.Is(err, errFmt) {
			fmt.Fprintln(os.Stderr, "cue-validate:", err)
		}
		os.Exit(1)
	}
}
