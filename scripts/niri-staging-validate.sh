#!/usr/bin/env bash
# niri-staging-validate.sh — Phase 4: validate the CUE-generated staging
# config with the real niri binary before anything touches production.
#
# Usage:
#   scripts/niri-staging-validate.sh
#
# Pipeline:
#   1. Generate staging config from CUE (cue-to-kdl.py)
#   2. Fidelity check: generated vs source semantics (fidelity-check.py)
#   3. niri validate on the staged config.kdl (config must parse as KDL
#      and be accepted by this niri version)
#   4. Report hashes of staging files for the record
#
# Production config (~/.config/niri) is never read or modified.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING="$REPO_ROOT/build/niri-staging"

echo "==> [1/3] Generate staging config from CUE"
"$REPO_ROOT/scripts/cue-to-kdl.py" --staging "$STAGING"

echo
echo "==> [2/3] Fidelity check (generated vs source semantics)"
"$REPO_ROOT/scripts/fidelity-check.py" --staging "$STAGING"

echo
echo "==> [3/3] niri validate on staging config"
niri validate -c "$STAGING/config.kdl"

echo
echo "==> Staging tree checksums"
(cd "$STAGING" && find . -type f | sort | xargs sha256sum)

echo
echo "OK: staging validation passes — generated artifacts are safe to review."
echo "    Apply to production only via: scripts/cue-validate.sh && deploy (see docs/CUE-MIGRATION.md)."
