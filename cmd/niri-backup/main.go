// niri-backup — checksummed backup of the tracked Niri config, with
// independent --verify support.
//
// Go port of scripts/backup-niri-config.sh (S187). Same inputs, same
// manifest format (sha256sum-compatible), same exit codes. The manifest is
// interoperable: backups created by the bash original verify with this tool
// and vice versa.
//
// Usage:
//
//	niri-backup                    # backup to default target
//	niri-backup --target DIR       # backup to DIR
//	niri-backup --verify DIR       # verify checksums in DIR
//	niri-backup --help
//
// Default target: ~/Backups/nightforge/pre-cue-migration/
//
// The backup tars the repo's Niri config tree (dotfiles/niri/.config/niri)
// and writes a SHA-256 manifest next to it. --verify recomputes the hashes
// and fails on any mismatch or missing file. This is the restore source for
// the CUE migration rollback path (see docs/CUE-MIGRATION.md).
package main

import (
	"archive/tar"
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/CR1MS0N-Operator/nightforge/internal/nfutil"
)

const usage = `backup-niri-config — checksummed backup of the tracked Niri config,
with independent --verify support.

Usage:
  backup-niri-config                 # backup to default target
  backup-niri-config --target DIR    # backup to DIR
  backup-niri-config --verify DIR    # verify checksums in DIR
  backup-niri-config --help

Default target: ~/Backups/nightforge/pre-cue-migration/

The backup tars the repo's Niri config tree (dotfiles/niri/.config/niri)
and writes a SHA-256 manifest next to it. --verify recomputes the hashes
and fails on any mismatch or missing file. This is the restore source for
the CUE migration rollback path (see docs/CUE-MIGRATION.md).
`

var (
	errUsage = errors.New("usage error (exit 2)")
	errFatal = errors.New("fatal")
)

func fileSHA(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// verify checks every manifest entry, sha256sum -c style. Returns the
// number of manifest lines and whether all matched.
func verify(target string) (int, bool) {
	manifest := filepath.Join(target, "manifest.sha256")
	if _, err := os.Stat(manifest); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: no manifest at %s\n", manifest)
		return 0, false
	}
	fmt.Printf("==> Verifying checksums in %s\n", target)

	b, err := os.ReadFile(manifest)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: cannot read manifest: %v\n", err)
		return 0, false
	}
	lines := strings.Split(strings.TrimRight(string(b), "\n"), "\n")
	ok := true
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) != 2 || len(fields[0]) != 64 {
			fmt.Fprintf(os.Stderr, "manifest: invalid line: %q\n", line)
			ok = false
			continue
		}
		want, path := fields[0], fields[1]
		if !filepath.IsAbs(path) {
			path = filepath.Join(target, path)
		}
		got, err := fileSHA(path)
		switch {
		case err != nil:
			fmt.Fprintf(os.Stderr, "sha256sum: %s: No such file or directory\n", fields[1])
			ok = false
		case got != want:
			fmt.Printf("%s: FAILED\n", fields[1])
			ok = false
		default:
			fmt.Printf("%s: OK\n", fields[1])
		}
	}
	return len(lines), ok
}

// tarGzDir archives the config tree as <base>/..., mirroring
// `tar -czf ARCHIVE -C <parent> <base>` (a "niri/" top-level entry).
func tarGzDir(configDir, archive string) error {
	f, err := os.Create(archive)
	if err != nil {
		return err
	}
	defer f.Close()
	gz := gzip.NewWriter(f)
	defer gz.Close()
	tw := tar.NewWriter(gz)
	defer tw.Close()

	parent := filepath.Dir(configDir)
	return filepath.WalkDir(configDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(parent, path)
		if err != nil {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		hdr, err := tar.FileInfoHeader(info, "")
		if err != nil {
			return err
		}
		hdr.Name = rel
		if err := tw.WriteHeader(hdr); err != nil {
			return err
		}
		if !info.Mode().IsRegular() {
			return nil
		}
		in, err := os.Open(path)
		if err != nil {
			return err
		}
		defer in.Close()
		_, err = io.Copy(tw, in)
		return err
	})
}

func backup(root, target string) error {
	configDir := filepath.Join(root, "dotfiles", "niri", ".config", "niri")
	if _, err := os.Stat(configDir); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: config tree missing: %s\n", configDir)
		return errFatal
	}
	if err := os.MkdirAll(target, 0o755); err != nil {
		return err
	}
	stamp := time.Now().Format("20060102-150405")
	archive := filepath.Join(target, "niri-config-"+stamp+".tar.gz")

	fmt.Printf("==> Backing up %s -> %s\n", configDir, archive)
	if err := tarGzDir(configDir, archive); err != nil {
		return err
	}

	fmt.Println("==> Writing SHA-256 manifest")
	h, err := fileSHA(archive)
	if err != nil {
		return err
	}
	lines := []string{h + "  " + filepath.Base(archive)}
	filepath.WalkDir(configDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.Type().IsRegular() {
			h, err := fileSHA(path)
			if err != nil {
				return err
			}
			lines = append(lines, h+"  "+path)
		}
		return nil
	})
	if err := os.WriteFile(filepath.Join(target, "manifest.sha256"), []byte(strings.Join(lines, "\n")+"\n"), 0o644); err != nil {
		return err
	}

	fmt.Println("==> Backup complete")
	ls := exec.Command("ls", "-la", target)
	ls.Stdout, ls.Stderr = os.Stdout, os.Stderr
	if err := ls.Run(); err != nil {
		return err
	}

	n, ok := verify(target)
	if !ok {
		return errFatal
	}
	fmt.Printf("OK: backup checksums verify (%d files).\n", n)

	fmt.Println()
	fmt.Printf("Restore: tar -xzf %s -C ~/.config/\n", archive)
	fmt.Printf("Verify any time: scripts/backup-niri-config.sh --verify %s\n", target)
	return nil
}

func run() error {
	root, err := nfutil.RepoRoot()
	if err != nil {
		return err
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	defaultTarget := filepath.Join(home, "Backups", "nightforge", "pre-cue-migration")

	target := defaultTarget
	mode := "backup"
	args := os.Args[1:]
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--target":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "--target requires a directory argument")
				return errUsage
			}
			target = args[i+1]
			i++
		case "--verify":
			mode = "verify"
			if i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
				target = args[i+1]
				i++
			}
		case "--help", "-h":
			fmt.Print(usage)
			return nil
		default:
			fmt.Fprintf(os.Stderr, "Unknown arg: %s\n", args[i])
			fmt.Fprint(os.Stderr, usage)
			return errUsage
		}
	}

	if mode == "verify" {
		n, ok := verify(target)
		if !ok {
			fmt.Fprintln(os.Stderr, "ERROR: backup checksum mismatch!")
			return errFatal
		}
		fmt.Printf("OK: backup checksums verify (%d files).\n", n)
		return nil
	}
	return backup(root, target)
}

func main() {
	if err := run(); err != nil {
		if !errors.Is(err, errUsage) && !errors.Is(err, errFatal) {
			fmt.Fprintln(os.Stderr, "niri-backup:", err)
		}
		switch {
		case errors.Is(err, errUsage):
			os.Exit(2)
		default:
			os.Exit(1)
		}
	}
}
