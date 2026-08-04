#!/usr/bin/env bash
set -euo pipefail

# Combined pipeline runner — runs failure-miner, proposal-engine, and gate-check in sequence.
# Run: scripts/harness/pipeline-runner.sh
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[pipeline] Running failure-miner..."
bash "$DIR/failure-miner.sh"

echo "[pipeline] Running proposal-engine..."
bash "$DIR/proposal-engine.sh"

echo "[pipeline] Running gate-check..."
bash "$DIR/gate-check.sh"

echo "[pipeline] Done"
