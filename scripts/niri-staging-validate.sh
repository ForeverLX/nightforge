#!/usr/bin/env bash
# Thin launcher for cmd/niri-staging-validate (Go) — S187 ported
# scripts/niri-staging-validate.sh. The Go pipeline builds its sibling
# tools (cue-to-kdl, fidelity-check) on demand into build/bin/.
# Builds the binary on demand into build/bin/ (gitignored) and execs it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/build/bin/niri-staging-validate"

if [[ ! -x "$BIN" ]]; then
    mkdir -p "$REPO_ROOT/build/bin"
    (cd "$REPO_ROOT" && go build -o "$BIN" ./cmd/niri-staging-validate)
fi

exec "$BIN" "$@"
