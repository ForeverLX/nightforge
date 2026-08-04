// niri-staging-validate — full staging validation pipeline.
//
// Go port of scripts/niri-staging-validate.sh (S187). Validates the
// CUE-generated staging config with the real niri binary before anything
// touches production.
//
// Pipeline:
//
//  1. Generate staging config from CUE (cue-to-kdl)
//  2. Fidelity check: generated vs source semantics (fidelity-check)
//  3. niri validate on the staged config.kdl (config must parse as KDL
//     and be accepted by this niri version)
//  4. Report hashes of staging files for the record
//
// Production config (~/.config/niri) is never read or modified.
//
// Usage:
//
//	niri-staging-validate
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"

	"github.com/ForeverLX/nightforge/internal/nfutil"
)

// runTool executes a sibling CUE tool, building it on demand into
// build/bin/ when no prebuilt binary exists (go run would recompile every
// invocation; the launcher scripts use the same build/bin convention).
func runTool(root, name string, args ...string) error {
	bin := filepath.Join(root, "build", "bin", name)
	if _, err := os.Stat(bin); err != nil {
		if err := os.MkdirAll(filepath.Dir(bin), 0o755); err != nil {
			return err
		}
		build := exec.Command("go", "build", "-o", bin, "./cmd/"+name)
		build.Dir = root
		build.Stderr = os.Stderr
		if err := build.Run(); err != nil {
			return fmt.Errorf("build %s: %w", name, err)
		}
	}
	cmd := exec.Command(bin, args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

// printTreeChecksums hashes every regular file in the tree, sha256sum
// format, paths prefixed "./" and sorted — matching `find . -type f |
// sort | xargs sha256sum`.
func printTreeChecksums(dir string) error {
	var files []string
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !d.IsDir() && d.Type().IsRegular() {
			rel, err := filepath.Rel(dir, path)
			if err != nil {
				return err
			}
			files = append(files, rel)
		}
		return nil
	})
	if err != nil {
		return err
	}
	sort.Strings(files)
	for _, rel := range files {
		f, err := os.Open(filepath.Join(dir, rel))
		if err != nil {
			return err
		}
		defer f.Close()
		h := sha256.New()
		if _, err := io.Copy(h, f); err != nil {
			return err
		}
		fmt.Printf("%s  ./%s\n", hex.EncodeToString(h.Sum(nil)), rel)
	}
	return nil
}

func run() error {
	root, err := nfutil.RepoRoot()
	if err != nil {
		return err
	}
	staging := filepath.Join(root, "build", "niri-staging")

	fmt.Println("==> [1/3] Generate staging config from CUE")
	if err := runTool(root, "cue-to-kdl", "--staging", staging); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println("==> [2/3] Fidelity check (generated vs source semantics)")
	if err := runTool(root, "fidelity-check", "--staging", staging); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println("==> [3/3] niri validate on staging config")
	validate := exec.Command("niri", "validate", "-c", filepath.Join(staging, "config.kdl"))
	validate.Stdout, validate.Stderr = os.Stdout, os.Stderr
	if err := validate.Run(); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println("==> Staging tree checksums")
	if err := printTreeChecksums(staging); err != nil {
		return err
	}

	fmt.Println()
	fmt.Println("OK: staging validation passes — generated artifacts are safe to review.")
	fmt.Println("    Apply to production only via: scripts/cue-validate.sh && deploy (see docs/CUE-MIGRATION.md).")
	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "niri-staging-validate:", err)
		os.Exit(1)
	}
}
