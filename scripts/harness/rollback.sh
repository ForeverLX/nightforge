#!/usr/bin/env bash
set -euo pipefail

# L7 Rollback — restores files from a named snapshot.
# Run: scripts/harness/rollback.sh <snapshot-name> [reason]
#
# TODO: The restore file map below mirrors snapshot-config.sh. When new files are
# added to snapshot-config.sh, this map must be updated to match. A future
# improvement would store the src→rel mapping inside each snapshot so rollback
# can restore without a hardcoded list.

SNAPSHOT_NAME="${1:-}"
REASON="${2:-manual rollback}"
SNAPSHOT_DIR="${HOME}/Github/nightforge/data/snapshots"
LOG_FILE="${SNAPSHOT_DIR}/snapshot-log.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Reverse file map: snapshot-relative-path → live-absolute-path
# Mirrors snapshot-config.sh mappings. Keep in sync.
declare -A RESTORE_MAP=(
    ["niri/config.kdl"]="${HOME}/.config/niri/config.kdl"
    ["AGENTS.md"]="${HOME}/Github/nightforge/AGENTS.md"
    ["go.mod"]="${HOME}/Github/nightforge/go.mod"
    ["data/tokens.json"]="${HOME}/Github/nightforge/data/tokens/current.json"
    ["data/pi-costs.json"]="${HOME}/Github/nightforge/data/cost/pi-costs.json"
    ["data/failures.json"]="${HOME}/Github/nightforge/data/failures/failures.json"
)

usage() {
    echo "Usage: $0 <snapshot-name> [reason]"
    if [ -f "$LOG_FILE" ]; then
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
    else
        echo "(no snapshots recorded — run snapshot-config.sh first)"
    fi
    exit 1
}

if [ -z "$SNAPSHOT_NAME" ]; then
    usage
fi

SNAPSHOT_PATH="${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"

# ── Restore ──────────────────────────────────────────────────────────
if [ -d "$SNAPSHOT_PATH" ]; then
    echo "Restoring from snapshot: $SNAPSHOT_NAME"
    restored=0
    skipped=0
    for rel in "${!RESTORE_MAP[@]}"; do
        src="${SNAPSHOT_PATH}/${rel}"
        dst="${RESTORE_MAP[$rel]}"
        if [ -f "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            echo "  restored: $dst"
            ((restored++)) || true
        else
            echo "  skipped (not in snapshot): $rel"
            ((skipped++)) || true
        fi
    done
    echo "Rollback complete: $restored file(s) restored, $skipped skipped."
else
    echo "Snapshot directory not found: $SNAPSHOT_PATH"
    echo "No files restored. Run snapshot-config.sh to create snapshots first."
fi

# ── Log ──────────────────────────────────────────────────────────────
mkdir -p "$SNAPSHOT_DIR"

python3 /dev/stdin "$SNAPSHOT_NAME" "$REASON" "$NOW" "$LOG_FILE" <<'PYEOF' || true
import json, sys

snap = sys.argv[1]
reason = sys.argv[2]
ts = sys.argv[3]
logfile = sys.argv[4]

log = {'snapshots': [], 'rollbacks': []}
try:
    with open(logfile) as f:
        log = json.load(f)
    log.setdefault('rollbacks', [])
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
