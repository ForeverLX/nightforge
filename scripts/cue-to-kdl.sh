#!/usr/bin/env bash
# Thin launcher for cmd/cue-to-kdl (Go) — S187 replaced scripts/cue-to-kdl.py.
# Builds the binary on demand into build/bin/ (gitignored) and execs it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/bin/cue-to-kdl"

if [[ ! -x "$BIN" ]]; then
    mkdir -p "$REPO_ROOT/build/bin"
    (cd "$REPO_ROOT" && go build -o "$BIN" ./cmd/cue-to-kdl)
fi

exec "$BIN" "$@"
