#!/usr/bin/env bash
set -euo pipefail

LABEL="${1:-baseline}"
SNAPSHOT_DIR="${HOME}/Github/nightforge/data/snapshots"
NOW=$(date -u +%Y%m%dT%H%M%SZ)
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SNAPSHOT_NAME="${NOW}-${LABEL}"
SNAPSHOT_PATH="${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"
LOG_FILE="${SNAPSHOT_DIR}/snapshot-log.json"

mkdir -p "${SNAPSHOT_PATH}"

snapshot_file() {
    local src="$1"
    local rel="${2:-$1}"
    if [ -f "$src" ]; then
        local dirpart
        dirpart="${rel%/*}"
        if [ "$dirpart" != "$rel" ]; then
            mkdir -p "${SNAPSHOT_PATH}/${dirpart}"
        fi
        cp "$src" "${SNAPSHOT_PATH}/${rel}"
    fi
}

snapshot_file "${HOME}/.config/niri/config.kdl" "niri/config.kdl"
snapshot_file "${HOME}/Github/nightforge/AGENTS.md" "AGENTS.md"
snapshot_file "${HOME}/Github/nightforge/go.mod" "go.mod"
snapshot_file "${HOME}/Github/nightforge/data/tokens/current.json" "data/tokens.json"
snapshot_file "${HOME}/Github/nightforge/data/cost/pi-costs.json" "data/pi-costs.json"
snapshot_file "${HOME}/Github/nightforge/data/failures/failures.json" "data/failures.json"

python3 /dev/stdin "${TS}" "${LABEL}" "${SNAPSHOT_NAME}" "${SNAPSHOT_DIR}" << 'PYEOF'
import json, sys, os

ts, label, name, sdir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
logfile = os.path.join(sdir, 'snapshot-log.json')

log = {'snapshots': [], 'rollbacks': []}
try:
    with open(logfile) as f:
        log = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

log['snapshots'].append({'name': name, 'timestamp': ts, 'label': label, 'type': 'snapshot'})

with open(logfile, 'w') as f:
    json.dump(log, f, indent=2)

print(f'Snapshot {name} recorded')
PYEOF

echo "Snapshot saved to ${SNAPSHOT_PATH}"
