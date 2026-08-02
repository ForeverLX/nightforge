#!/usr/bin/env bash
# cue-validate.sh — validate the NightForge CUE config against the schema.
#
# Usage:
#   scripts/cue-validate.sh
#
# Checks:
#   1. cue fmt — formatting is canonical
#   2. cue vet — data satisfies schema constraints
#   3. structural sanity via cue export (counts printed for the record)
#
# Exit 0 on success, non-zero on any failure.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUE_DIR="$REPO_ROOT/cue"

cd "$CUE_DIR"

echo "==> cue fmt --check"
if ! out=$(cue fmt --check . 2>&1); then
    echo "ERROR: CUE formatting drift:" >&2
    echo "$out" >&2
    echo "Run: (cd cue && cue fmt .)" >&2
    exit 1
fi

echo "==> cue vet"
cue vet .

echo "==> cue export (counts)"
cue export . --out json | jq -r '
  .config |
  "spawn-at-startup: \(.spawnAtStartup | length)" ,
  "binds:            \(.binds | length)" ,
  "window-rules:     \(.windowRules | length)"
'

echo "OK: CUE schemas validate (nightforge.niri)."
