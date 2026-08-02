#!/usr/bin/env bash
# Thin launcher for cmd/niri-backup (Go) — S187 ported scripts/backup-niri-config.sh.
# Builds the binary on demand into build/bin/ (gitignored) and execs it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/bin/niri-backup"

if [[ ! -x "$BIN" ]]; then
    mkdir -p "$REPO_ROOT/build/bin"
    (cd "$REPO_ROOT" && go build -o "$BIN" ./cmd/niri-backup)
fi

exec "$BIN" "$@"
