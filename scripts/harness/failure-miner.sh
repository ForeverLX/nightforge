#!/usr/bin/env bash
set -euo pipefail

# L4 Failure Mining — reads Pi session data, classifies failures into 21 AgentEval categories.
# Run: scripts/harness/failure-miner.sh
# Output: data/failures/failures.json
# Taxonomy: 10-layer-stack/l4-taxonomy-21-categories.md

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

# 21-category AgentEval taxonomy
categories = {
    # P0: Already covered by old taxonomy
    'tool_error':        {'id': 'tool_error',        'label': 'Tool Execution Error',        'severity': 'medium',  'count': 0, 'p': 0},
    'model_error':       {'id': 'model_error',        'label': 'Model API Error',             'severity': 'high',    'count': 0, 'p': 0},
    'timeout':           {'id': 'timeout',            'label': 'Timeout',                     'severity': 'medium',  'count': 0, 'p': 0},
    'auth_error':        {'id': 'auth_error',         'label': 'Authentication Error',        'severity': 'high',    'count': 0, 'p': 0},
    'workflow_error':    {'id': 'workflow_error',     'label': 'Workflow Disruption',         'severity': 'high',    'count': 0, 'p': 0},
    # P0: New categories (data partially available)
    'rate_limit':        {'id': 'rate_limit',         'label': 'Provider Rate Limit',         'severity': 'medium',  'count': 0, 'p': 0},
    'cost':              {'id': 'cost',               'label': 'Cost Overrun',                'severity': 'medium',  'count': 0, 'p': 0},
    # P1: New categories (partial data)
    'planning':          {'id': 'planning',           'label': 'Planning Loop / Goal Drift',  'severity': 'high',    'count': 0, 'p': 0},
    'context_window':    {'id': 'context_window',     'label': 'Context Window Overflow',     'severity': 'high',    'count': 0, 'p': 0},
    'routing':           {'id': 'routing',            'label': 'Routing Mismatch',            'severity': 'medium',  'count': 0, 'p': 0},
    'latency':           {'id': 'latency',            'label': 'High Latency',               'severity': 'medium',  'count': 0, 'p': 0},
    'deadlock':          {'id': 'deadlock',           'label': 'Agent Deadlock',              'severity': 'critical','count': 0, 'p': 0},
    # P2: New categories (needs new data sources)
    'tool_selection':    {'id': 'tool_selection',     'label': 'Wrong Tool Selected',         'severity': 'medium',  'count': 0, 'p': 0},
    'reasoning':         {'id': 'reasoning',          'label': 'Reasoning Error',             'severity': 'high',    'count': 0, 'p': 0},
    'memory':            {'id': 'memory',             'label': 'Memory / State Loss',         'severity': 'high',    'count': 0, 'p': 0},
    'hallucination':     {'id': 'hallucination',      'label': 'Hallucination',               'severity': 'high',    'count': 0, 'p': 0},
    'security':          {'id': 'security',           'label': 'Security Violation',          'severity': 'critical','count': 0, 'p': 0},
    'authz_escalation':  {'id': 'authz_escalation',   'label': 'Authorization Escalation',    'severity': 'critical','count': 0, 'p': 0},
    'data_loss':         {'id': 'data_loss',          'label': 'Data Loss',                   'severity': 'critical','count': 0, 'p': 0},
    'resource_error':    {'id': 'resource_error',     'label': 'Resource Exhaustion',         'severity': 'critical','count': 0, 'p': 0},
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
    msg_count = s.get('message_count', 0)
    duration = s.get('duration_seconds', 0)

    if err_count == 0 and stop_reason != 'error':
        continue

    # Classification logic
    cat_id = 'workflow_error'  # default

    # Priority 1: Explicit stop reasons
    if stop_reason == 'error':
        cat_id = 'workflow_error'
    elif stop_reason == 'timeout':
        cat_id = 'timeout'
    elif stop_reason == 'rate_limit' or stop_reason == '429':
        cat_id = 'rate_limit'
    elif stop_reason == 'auth' or stop_reason == '401' or stop_reason == '403':
        cat_id = 'auth_error'

    # Priority 2: Error count patterns
    elif err_count > 10:
        # High error count suggests systemic issue
        if 'rate' in str(s.get('last_error', '')).lower() or '429' in str(s.get('last_error', '')):
            cat_id = 'rate_limit'
        elif 'timeout' in str(s.get('last_error', '')).lower():
            cat_id = 'timeout'
        elif 'auth' in str(s.get('last_error', '')).lower() or 'key' in str(s.get('last_error', '')).lower():
            cat_id = 'auth_error'
        else:
            cat_id = 'tool_error'
    elif err_count > 5:
        cat_id = 'tool_error'
    elif err_count > 0:
        # Low error count — check for specific patterns
        last_err = str(s.get('last_error', '')).lower()
        if 'rate' in last_err or '429' in last_err:
            cat_id = 'rate_limit'
        elif 'timeout' in last_err:
            cat_id = 'timeout'
        elif 'context' in last_err or 'token' in last_err or 'overflow' in last_err:
            cat_id = 'context_window'
        elif 'auth' in last_err or 'key' in last_err or 'credential' in last_err:
            cat_id = 'auth_error'
        else:
            cat_id = 'tool_error'

    # Priority 3: Heuristic detection (P1 categories)
    # Planning loop: many messages but no progress (high msg count + error)
    if msg_count > 50 and err_count > 3 and cat_id == 'workflow_error':
        cat_id = 'planning'

    # Deadlock: very long duration with errors
    if duration > 3600 and err_count > 0 and cat_id == 'workflow_error':
        cat_id = 'deadlock'

    # Cost overrun: session ran long with many errors
    if duration > 1800 and err_count > 5 and cat_id == 'tool_error':
        cat_id = 'cost'

    failure = {
        'session_id': sid,
        'model': model,
        'provider': provider,
        'error_count': err_count,
        'stop_reason': stop_reason,
        'message_count': msg_count,
        'duration_seconds': duration,
        'category': cat_id
    }
    failures.append(failure)
    categories[cat_id]['count'] += 1

# Filter empty categories
active_categories = [c for c in categories.values() if c['count'] > 0]

output = {
    'taxonomy_version': '2.0',
    'taxonomy_source': 'AgentEval 21-category standard',
    'failures': failures,
    'categories': active_categories,
    'total_failures': len(failures),
    'category_counts': {c['id']: c['count'] for c in active_categories},
    'last_updated': now
}

with open(os.path.join(outdir, 'failures.json'), 'w') as f:
    json.dump(output, f, indent=2)

# Summary by priority
p0 = sum(c['count'] for c in active_categories if c['id'] in ('tool_error','model_error','timeout','auth_error','workflow_error','rate_limit','cost'))
p1 = sum(c['count'] for c in active_categories if c['id'] in ('planning','context_window','routing','latency','deadlock'))
p2 = sum(c['count'] for c in active_categories if c['id'] in ('tool_selection','reasoning','memory','hallucination','security','authz_escalation','data_loss','resource_error'))

print(f'Mined {len(failures)} failures across {len(active_categories)} categories')
print(f'  P0 (covered): {p0} | P1 (partial): {p1} | P2 (needs data): {p2}')
PYEOF
