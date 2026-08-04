#!/usr/bin/env bash
set -euo pipefail

# L4 Failure Mining — reads Pi session data, classifies failures, outputs structured report.
# Run: scripts/harness/failure-miner.sh
# Output: data/failures/failures.json

OUT_DIR="$HOME/Github/nightforge/data/failures"
PI_DATA="$HOME/Github/nightforge/data/cost/pi-costs.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$OUT_DIR"

if [ ! -f "$PI_DATA" ]; then
  echo '{"failures":[],"categories":[],"total_failures":0,"last_updated":"'"$NOW"'"}' > "$OUT_DIR/failures.json"
  echo "No Pi session data available"
  exit 0
fi

python3 /dev/stdin "$PI_DATA" "$OUT_DIR" "$NOW" <<'PYEOF' || true
import json, sys, os

pifile = sys.argv[1]
outdir = sys.argv[2]
now = sys.argv[3]

with open(pifile) as f:
    pi = json.load(f)

sessions = pi.get('sessions', [])

# Classify failures by error category
categories = {
    'tool_error': {'id': 'tool_error', 'label': 'Tool Execution Error', 'severity': 'medium', 'sessions': [], 'count': 0},
    'api_error': {'id': 'api_error', 'label': 'API / Provider Error', 'severity': 'high', 'sessions': [], 'count': 0},
    'timeout': {'id': 'timeout', 'label': 'Timeout', 'severity': 'medium', 'sessions': [], 'count': 0},
    'auth_error': {'id': 'auth_error', 'label': 'Authentication Error', 'severity': 'high', 'sessions': [], 'count': 0},
    'stop_reason_error': {'id': 'stop_reason_error', 'label': 'Session Terminated by Error', 'severity': 'high', 'sessions': [], 'count': 0},
    'unknown': {'id': 'unknown', 'label': 'Unknown Failure', 'severity': 'low', 'sessions': [], 'count': 0},
}

failures = []
for s in sessions:
    sid = s.get('session_id', '')
    if not sid:
        sid = s.get('session_file', 'unknown')

    err_count = s.get('errors', 0)
    stop_reason = s.get('last_stop_reason', '')
    model = s.get('model', 'unknown')
    provider = s.get('provider', 'unknown')

    if err_count == 0 and stop_reason != 'error':
        continue

    # Categorize
    cat_id = 'unknown'
    if err_count > 0 and stop_reason == 'error':
        cat_id = 'stop_reason_error'
    elif err_count > 5:
        cat_id = 'tool_error'
    elif err_count > 0 and stop_reason == 'timeout':
        cat_id = 'timeout'
    elif err_count > 0:
        cat_id = 'tool_error'

    failure = {
        'session_id': sid,
        'model': model,
        'provider': provider,
        'error_count': err_count,
        'stop_reason': stop_reason,
        'message_count': s.get('message_count', 0),
        'category': cat_id
    }
    failures.append(failure)
    categories[cat_id]['sessions'].append(sid)
    categories[cat_id]['count'] += 1

# Filter empty categories
active_categories = [c for c in categories.values() if c['count'] > 0]
for c in active_categories:
    del c['sessions']  # don't bloat output with session lists

output = {
    'failures': failures,
    'categories': active_categories,
    'total_failures': len(failures),
    'last_updated': now
}

with open(os.path.join(outdir, 'failures.json'), 'w') as f:
    json.dump(output, f, indent=2)

print(f'Mined {len(failures)} failures across {len(active_categories)} categories')
PYEOF
