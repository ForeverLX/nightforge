#!/usr/bin/env bash
set -euo pipefail

# L7 Rollback — records a rollback event. Does not actually restore.
# Run: scripts/harness/rollback.sh <snapshot-name> [reason]

SNAPSHOT_NAME="${1:-}"
REASON="${2:-manual rollback}"
LOG_FILE="${NIGHTFORGE_DATA_DIR:-$HOME/nightforge/data}/snapshots/snapshot-log.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$SNAPSHOT_NAME" ]; then
    echo "Usage: $0 <snapshot-name> [reason]"
    echo "Available snapshots:"
    python3 -c "
import json
try:
    with open('$LOG_FILE') as f:
        log = json.load(f)
        for s in log.get('snapshots', []):
            print(f'  {s[\"name\"]}  ({s[\"label\"]})  {s[\"timestamp\"][:19]}')
except: pass
" 2>/dev/null
    exit 1
fi

mkdir -p "$(dirname "$LOG_FILE")"

python3 /dev/stdin "$SNAPSHOT_NAME" "$REASON" "$NOW" "$LOG_FILE" <<'PYEOF' || true
import json, sys, os

snap = sys.argv[1]
reason = sys.argv[2]
ts = sys.argv[3]
logfile = sys.argv[4]

log = {'snapshots': [], 'rollbacks': []}
try:
    with open(logfile) as f:
        log = json.load(f)
    log['rollbacks'] = log.get('rollbacks', [])
    log['rollbacks'].append({
        'snapshot': snap,
        'timestamp': ts,
        'reason': reason
    })
    with open(logfile, 'w') as f:
        json.dump(log, f, indent=2)
    print(f'Rollback to {snap} recorded')
except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
PYEOF
