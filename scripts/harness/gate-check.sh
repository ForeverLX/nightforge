#!/usr/bin/env bash
set -euo pipefail

# L6 Validation Gate — evaluates proposals against gate rules.
# Run: scripts/harness/gate-check.sh
# Output: data/gates/gates.json

PROPOSALS="$HOME/Github/nightforge/data/proposals/proposals.json"
FAILURES="$HOME/Github/nightforge/data/failures/failures.json"
OUT_DIR="$HOME/Github/nightforge/data/gates"
APPROVALS="$HOME/Github/nightforge/data/gates/operator-approvals.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$OUT_DIR"

python3 /dev/stdin "$PROPOSALS" "$FAILURES" "$OUT_DIR" "$NOW" "$APPROVALS" <<'PYEOF' || true
import json, sys, os

propfile = sys.argv[1]
failfile = sys.argv[2]
outdir = sys.argv[3]
now = sys.argv[4]
approvfile = sys.argv[5]

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
        # category_counts maps failure_source category id -> number of recorded
        # failures; used as the quantitative impact evidence for rule G1.
        category_counts = fd.get('category_counts', {})
except (FileNotFoundError, json.JSONDecodeError):
    pass
if 'category_counts' not in dir():
    category_counts = {}

# ---------------------------------------------------------------------------
# G1 heuristic (DERIVED FROM DATA, not a constant):
#   Primary: impact_evidence = count of recorded failures for the proposal's
#     'failure_source' category (looked up in failures.json category_counts).
#     G1 passes when that count >= G1_THRESHOLD (default 5), matching the gate
#     description "must address at least 5 failures".
#   Fallback (no/unknown failure_source, or no category data): G1 passes when
#     the proposal's title+description reference >= G1_INDICATOR_THRESHOLD
#     (default 2) DISTINCT issue-indicator keywords from a fixed failure/problem
#     vocabulary. This keeps G1 decidable from the proposal body alone.
# Thresholds are overridable via env vars (G1_THRESHOLD / G1_INDICATOR_THRESHOLD).
# Evidence for every proposal is emitted into gates.json under 'impact_evidence'.
G1_THRESHOLD = int(os.environ.get('G1_THRESHOLD', '5'))
G1_INDICATOR_THRESHOLD = int(os.environ.get('G1_INDICATOR_THRESHOLD', '2'))
G1_INDICATORS = ('error', 'fail', 'failure', 'bug', 'crash', 'exception',
                 'timeout', 'retry', 'issue', 'broken', 'malfunction',
                 'disruption', 'warning', 'defect', 'problem')

def g1_eval(proposal):
    """Return (status, evidence) for rule G1 from proposal + failure data."""
    fs = proposal.get('failure_source')
    if fs and fs in category_counts:
        count = category_counts[fs]
        ev = {'type': 'failure_source_count', 'failure_source': fs,
              'failure_source_count': count, 'threshold': G1_THRESHOLD}
        return ('pass' if count >= G1_THRESHOLD else 'fail'), ev
    text = ' '.join(str(proposal.get(k, '') or '') for k in ('title', 'description')).lower()
    found = sorted({w for w in G1_INDICATORS if w in text})
    ev = {'type': 'indicator_count', 'indicators': found,
          'indicator_threshold': G1_INDICATOR_THRESHOLD}
    return ('pass' if len(found) >= G1_INDICATOR_THRESHOLD else 'fail'), ev

# ---------------------------------------------------------------------------
# Operator approval gate (G6 / operator_gate) — Decision #50/#58: humans and
# agents are first-class. Reads data/gates/operator-approvals.json:
#   {"approvals": ["<proposal_id>", ...], "rejections": [...]}
# Missing file or absent id -> 'pending_approval'. A proposal's OVERALL status
# is 'pass' ONLY when every rule G1-G5 passes AND the operator approved it.
approval_file_present = False
approvals = []
rejections = []
try:
    with open(approvfile) as f:
        ad = json.load(f)
        approvals = list(ad.get('approvals', []))
        rejections = list(ad.get('rejections', []))
        approval_file_present = True
except (FileNotFoundError, json.JSONDecodeError):
    pass
approvals = set(approvals)
rejections = set(rejections)

def operator_status(proposal_id):
    if proposal_id in rejections:
        return 'rejected'
    if proposal_id in approvals:
        return 'approved'
    return 'pending_approval'

def overall_status(results, op_status):
    """Rules decide first; operator approval/rejection then gates 'pass'."""
    if op_status == 'rejected':
        return 'rejected'
    rules = all(v == 'pass' for v in results.values())
    if not rules:
        return 'fail'
    if op_status == 'approved':
        return 'pass'
    return 'pending_approval'

# Evaluate each proposal against gates
proposal_results = []
for p in proposals:
    results = {}
    # G1: Impact Threshold — derived from failure_source count or indicators
    g1_status, g1_evidence = g1_eval(p)
    results['G1'] = g1_status
    if g1_status == 'pass':
        gates[0]['pass_count'] += 1
    else:
        gates[0]['fail_count'] += 1

    # Operator approval (G6) — decided outside the 5 rule gates
    op_status = operator_status(p['id'])

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
        'failure_source': p.get('failure_source'),
        'impact_evidence': g1_evidence,
        'gates': results,
        'operator_status': op_status,
        'overall': overall_status(results, op_status)
    })

# Update gate overall status
for g in gates:
    g['total_evaluated'] = g['pass_count'] + g['fail_count']
    if g['fail_count'] > 0:
        g['status'] = 'fail'

op_counts = {'approved': 0, 'rejected': 0, 'pending_approval': 0}
for r in proposal_results:
    op_counts[r['operator_status']] += 1

output = {
    'gates': gates,
    'operator_gate': {
        'present': approval_file_present,
        'approval_file': approvfile,
        'approved_ids': sorted(approvals),
        'rejected_ids': sorted(rejections),
        'summary': op_counts
    },
    'proposal_results': proposal_results,
    'total_proposals_evaluated': len(proposals),
    'last_updated': now
}

with open(os.path.join(outdir, 'gates.json'), 'w') as f:
    json.dump(output, f, indent=2)

print(f'Evaluated {len(proposals)} proposals across {len(gates)} rule gates (plus operator gate)')
PYEOF
