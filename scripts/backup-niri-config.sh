#!/usr/bin/env bash
# backup-niri-config.sh — checksummed backup of the tracked Niri config,
# with independent --verify support.
#
# Usage:
#   scripts/backup-niri-config.sh                 # backup to default target
#   scripts/backup-niri-config.sh --target DIR    # backup to DIR
#   scripts/backup-niri-config.sh --verify DIR    # verify checksums in DIR
#   scripts/backup-niri-config.sh --help
#
# Default target: ~/Backups/nightforge/pre-cue-migration/
#
# The backup tars the repo's Niri config tree (dotfiles/niri/.config/niri)
# and writes a SHA-256 manifest next to it. --verify recomputes the hashes
# and fails on any mismatch or missing file. This is the restore source for
# the CUE migration rollback path (see docs/CUE-MIGRATION.md).

set -euo pipefail

DEFAULT_TARGET="$HOME/Backups/nightforge/pre-cue-migration"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/dotfiles/niri/.config/niri"
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | grep '^#' | sed 's/^# \{0,1\}//'
}

verify() {
    local target="$1"
    local manifest="$target/manifest.sha256"
    if [[ ! -f "$manifest" ]]; then
        echo "ERROR: no manifest at $manifest" >&2
        exit 1
    fi
    echo "==> Verifying checksums in $target"
    if (cd "$target" && sha256sum -c manifest.sha256); then
        echo "OK: backup checksums verify ($(wc -l < "$manifest") files)."
    else
        echo "ERROR: backup checksum mismatch!" >&2
        exit 1
    fi
}

TARGET="$DEFAULT_TARGET"
MODE="backup"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)  TARGET="$2"; shift 2 ;;
        --verify)  MODE="verify"
                    if [[ $# -ge 2 && "${2:0:1}" != "-" ]]; then TARGET="$2"; shift; fi
                    shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
    esac
 done

if [[ "$MODE" == "verify" ]]; then
    verify "$TARGET"
    exit 0
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "ERROR: config tree missing: $CONFIG_DIR" >&2
    exit 1
fi

mkdir -p "$TARGET"
ARCHIVE="$TARGET/niri-config-$STAMP.tar.gz"

echo "==> Backing up $CONFIG_DIR -> $ARCHIVE"
tar -czf "$ARCHIVE" -C "$(dirname "$CONFIG_DIR")" "$(basename "$CONFIG_DIR")"

echo "==> Writing SHA-256 manifest"
(
    (cd "$TARGET" && sha256sum "$(basename "$ARCHIVE")")
    find "$CONFIG_DIR" -type f -exec sha256sum {} +
) > "$TARGET/manifest.sha256"

echo "==> Backup complete"
ls -la "$TARGET"
verify "$TARGET"

echo
echo "Restore: tar -xzf $ARCHIVE -C ~/.config/"
echo "Verify any time: scripts/backup-niri-config.sh --verify $TARGET"
