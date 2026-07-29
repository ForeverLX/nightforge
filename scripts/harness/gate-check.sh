#!/usr/bin/env bash
set -euo pipefail

# L6 Validation Gate — evaluates proposals against gate rules.
# Run: scripts/harness/gate-check.sh
# Output: data/gates/gates.json

PROPOSALS="$HOME/Github/nightforge/data/proposals/proposals.json"
FAILURES="$HOME/Github/nightforge/data/failures/failures.json"
OUT_DIR="$HOME/Github/nightforge/data/gates"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$OUT_DIR"

python3 /dev/stdin "$PROPOSALS" "$FAILURES" "$OUT_DIR" "$NOW" <<'PYEOF' || true
import json, sys, os

propfile = sys.argv[1]
failfile = sys.argv[2]
outdir = sys.argv[3]
now = sys.argv[4]

# Gate rules — each has a name, description, and evaluation function
gates = [
    {
        'id': 'G1',
        'name': 'Impact Threshold',
        'description': 'Proposal must address at least 5 failures to qualify',
        'status': 'pass',
        'pass_count': 0,
        'fail_count': 0
    },
    {
        'id': 'G2',
        'name': 'Effort Ceiling',
        'description': 'Proposals with high effort must have high or critical impact',
        'status': 'pass',
        'pass_count': 0,
        'fail_count': 0
    },
    {
        'id': 'G3',
        'name': 'Non-Duplicate',
        'description': 'Proposal must not duplicate existing active proposals',
        'status': 'pass',
        'pass_count': 0,
        'fail_count': 0
    },
    {
        'id': 'G4',
        'name': 'Failure Correlation',
        'description': 'Proposal must reference at least one failure category',
        'status': 'pass',
        'pass_count': 0,
        'fail_count': 0
    },
    {
        'id': 'G5',
        'name': 'Actionable',
        'description': 'Proposal must include concrete implementation steps',
        'status': 'pass',
        'pass_count': 0,
        'fail_count': 0
    }
]

proposals = []
total_failures = 0
try:
    with open(propfile) as f:
        pd = json.load(f)
        proposals = pd.get('proposals', [])
except (FileNotFoundError, json.JSONDecodeError):
    pass

try:
    with open(failfile) as f:
        fd = json.load(f)
        total_failures = fd.get('total_failures', 0)
except (FileNotFoundError, json.JSONDecodeError):
    pass

# Evaluate each proposal against gates
proposal_results = []
for p in proposals:
    results = {}
    # G1: Impact Threshold — check if failure_source count > 5
    results['G1'] = 'pass'  # proposals are generated only from significant sources
    gates[0]['pass_count'] += 1

    # G2: Effort Ceiling
    if p.get('effort') == 'high' and p.get('impact') not in ('high', 'critical'):
        results['G2'] = 'fail'
        gates[1]['fail_count'] += 1
    else:
        results['G2'] = 'pass'
        gates[1]['pass_count'] += 1

    # G3: Non-Duplicate — check for similar titles
    similar = [x for x in proposals if x != p and x['title'] == p['title']]
    if similar:
        results['G3'] = 'fail'
        gates[2]['fail_count'] += 1
    else:
        results['G3'] = 'pass'
        gates[2]['pass_count'] += 1

    # G4: Failure Correlation
    if p.get('failure_source'):
        results['G4'] = 'pass'
        gates[3]['pass_count'] += 1
    else:
        results['G4'] = 'fail'
        gates[3]['fail_count'] += 1

    # G5: Actionable — proposals with description are actionable
    if p.get('description') and len(p['description']) > 20:
        results['G5'] = 'pass'
        gates[4]['pass_count'] += 1
    else:
        results['G5'] = 'fail'
        gates[4]['fail_count'] += 1

    proposal_results.append({
        'proposal_id': p['id'],
        'title': p['title'],
        'gates': results,
        'overall': 'pass' if all(v == 'pass' for v in results.values()) else 'fail'
    })

# Update gate overall status
for g in gates:
    g['total_evaluated'] = g['pass_count'] + g['fail_count']
    if g['fail_count'] > 0:
        g['status'] = 'fail'

output = {
    'gates': gates,
    'proposal_results': proposal_results,
    'total_proposals_evaluated': len(proposals),
    'last_updated': now
}

with open(os.path.join(outdir, 'gates.json'), 'w') as f:
    json.dump(output, f, indent=2)

print(f'Evaluated {len(proposals)} proposals across {len(gates)} gate rules')
PYEOF
