#!/usr/bin/env bash
# Thin launcher for cmd/fidelity-check (Go) — S187 replaced scripts/fidelity-check.py.
# Builds the binary on demand into build/bin/ (gitignored) and execs it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/bin/fidelity-check"

if [[ ! -x "$BIN" ]]; then
    mkdir -p "$REPO_ROOT/build/bin"
    (cd "$REPO_ROOT" && go build -o "$BIN" ./cmd/fidelity-check)
fi

exec "$BIN" "$@"
