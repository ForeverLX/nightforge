#!/usr/bin/env bash
set -euo pipefail

# L5 Proposal Engine — reads failure data, generates improvement proposals.
# Run: scripts/harness/proposal-engine.sh
# Output: data/proposals/proposals.json

FAILURES="$HOME/Github/nightforge/data/failures/failures.json"
OUT_DIR="$HOME/Github/nightforge/data/proposals"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$OUT_DIR"

if [ ! -f "$FAILURES" ]; then
  echo '{"proposals":[],"total_proposals":0,"last_updated":"'"$NOW"'"}' > "$OUT_DIR/proposals.json"
  exit 0
fi

python3 /dev/stdin "$FAILURES" "$OUT_DIR" "$NOW" <<'PYEOF' || true
import json, sys, os

failfile = sys.argv[1]
outdir = sys.argv[2]
now = sys.argv[3]

with open(failfile) as f:
    data = json.load(f)

categories = {c['id']: c for c in data.get('categories', [])}
total_failures = data.get('total_failures', 0)

# Generate proposals based on failure categories
proposals = []

if 'tool_error' in categories and categories['tool_error']['count'] > 5:
    proposals.append({
        'id': 'P1',
        'title': 'Reduce Tool Execution Errors',
        'description': f"Tool execution errors account for {categories['tool_error']['count']} failures. "
                       'Consider adding retry logic, timeout handling, and better error reporting.',
        'category': 'reliability',
        'impact': 'high',
        'effort': 'medium',
        'status': 'pending',
        'failure_source': 'tool_error'
    })

if 'model_error' in categories and categories['model_error']['count'] > 0:
    proposals.append({
        'id': 'P2',
        'title': 'API Provider Error Handling',
        'description': f"Model API errors account for {categories['model_error']['count']} failures. "
                       'Consider provider fallback, retry on transient model errors, and clearer model-error surfacing.',
        'category': 'reliability',
        'impact': 'high',
        'effort': 'medium',
        'status': 'pending',
        'failure_source': 'model_error'
    })

if 'timeout' in categories and categories['timeout']['count'] > 0:
    proposals.append({
        'id': 'P3',
        'title': 'Increase Timeout Thresholds',
        'description': f"Timeouts account for {categories['timeout']['count']} failures. "
                       'Consider increasing default timeouts for long-running operations.',
        'category': 'performance',
        'impact': 'medium',
        'effort': 'low',
        'status': 'pending',
        'failure_source': 'timeout'
    })

if 'workflow_error' in categories and categories['workflow_error']['count'] > 3:
    proposals.append({
        'id': 'P4',
        'title': 'Session Recovery on Error',
        'description': f"{categories['workflow_error']['count']} workflows terminated by error. "
                       'Implement session checkpoint and recovery mechanism.',
        'category': 'reliability',
        'impact': 'high',
        'effort': 'high',
        'status': 'pending',
        'failure_source': 'workflow_error'
    })

if total_failures > 50:
    proposals.append({
        'id': 'P5',
        'title': 'Proactive Failure Monitoring',
        'description': f"Total failures ({total_failures}) exceed threshold. "
                       'Set up alerting when failure rate exceeds 10% of sessions.',
        'category': 'monitoring',
        'impact': 'medium',
        'effort': 'low',
        'status': 'pending',
        'failure_source': 'all'
    })

output = {
    'proposals': proposals,
    'total_proposals': len(proposals),
    'last_updated': now
}

with open(os.path.join(outdir, 'proposals.json'), 'w') as f:
    json.dump(output, f, indent=2)

print(f'Generated {len(proposals)} proposals from {total_failures} failures')
PYEOF
