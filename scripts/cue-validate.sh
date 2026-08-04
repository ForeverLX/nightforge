#!/usr/bin/env bash
# Thin launcher for cmd/cue-validate (Go) — S187 ported scripts/cue-validate.sh.
# Builds the binary on demand into build/bin/ (gitignored) and execs it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/bin/cue-validate"

if [[ ! -x "$BIN" ]]; then
    mkdir -p "$REPO_ROOT/build/bin"
    (cd "$REPO_ROOT" && go build -o "$BIN" ./cmd/cue-validate)
fi

exec "$BIN" "$@"
