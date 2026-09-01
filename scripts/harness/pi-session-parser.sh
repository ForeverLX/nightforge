#!/usr/bin/env bash
set -euo pipefail

SESSION_DIR="$HOME/.omp/agent/sessions"
OUT_DIR="${NIGHTFORGE_DATA_DIR:-$HOME/nightforge/data}/cost"
OUT_SESSIONS="$OUT_DIR/pi-costs.json"
OUT_DAILY="$OUT_DIR/pi-costs-daily.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$OUT_DIR"

find "$SESSION_DIR" -name "*.jsonl" 2>/dev/null | while IFS= read -r f; do
  python3 /dev/stdin "$f" 2>/dev/null <<'PYEOF' || true
import json, sys, os

path = sys.argv[1]
basename = os.path.basename(path)

session = {
    'session_file': basename,
    'session_id': None,
    'started_at': None,
    'ended_at': None,
    'title': None,
    'model': None,
    'provider': None,
    'api': None,
    'tokens_in': 0,
    'tokens_out': 0,
    'total_tokens': 0,
    'cost': 0.0,
    'message_count': 0,
    'tool_calls': 0,
    'last_stop_reason': None,
    'errors': 0
}

try:
    with open(path, 'r') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue

            etype = ev.get('type', '')

            if etype == 'session':
                session['session_id'] = ev.get('id')
                session['started_at'] = ev.get('timestamp')

            elif etype == 'title':
                session['title'] = ev.get('title')

            elif etype == 'model_change':
                if not session['model']:
                    model = ev.get('model', '')
                    if '/' in model:
                        parts = model.split('/', 1)
                        session['provider'] = parts[0]
                        session['model'] = parts[1]
                    else:
                        session['model'] = model

            elif etype == 'message':
                msg = ev.get('message', {})
                role = msg.get('role', '')
                session['message_count'] += 1

                if role == 'assistant':
                    provider = ev.get('provider') or msg.get('provider', '')
                    model = ev.get('model') or msg.get('model', '')
                    api = ev.get('api') or msg.get('api', '')

                    if provider and not session['provider']:
                        session['provider'] = provider
                    if model and not session['model']:
                        session['model'] = model
                    if api and not session['api']:
                        session['api'] = api

                    usage = msg.get('usage', {}) or ev.get('usage', {})
                    if usage:
                        tokens_in = int(usage.get('input', 0))
                        tokens_out = int(usage.get('output', 0))
                        total_tokens = int(usage.get('totalTokens', 0))
                        cost_obj = usage.get('cost', {})
                        cost_total = 0.0
                        if isinstance(cost_obj, dict):
                            cost_total = float(cost_obj.get('total', 0))
                        if cost_total < 0 or cost_total > 100.0:
                            cost_total = 0.0

                        session['tokens_in'] += tokens_in
                        session['tokens_out'] += tokens_out
                        session['total_tokens'] += total_tokens
                        session['cost'] += cost_total

                    stop = msg.get('stopReason') or ev.get('stopReason', '')
                    if stop:
                        session['last_stop_reason'] = stop

                content = msg.get('content', [])
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get('type') == 'toolCall':
                            session['tool_calls'] += 1

                if role == 'toolResult':
                    if msg.get('isError'):
                        session['errors'] += 1

            elif etype == 'custom':
                if ev.get('customType') == 'session_exit':
                    session['ended_at'] = ev.get('timestamp')
                    reason = ev.get('data', {}).get('reason', '')
                    if reason:
                        session['last_stop_reason'] = reason

except Exception:
    pass

session['cost'] = round(session['cost'], 6)

if session['session_id'] or session['total_tokens'] > 0:
    print(json.dumps(session))
PYEOF
done > "$OUT_SESSIONS.tmp"

if [ ! -s "$OUT_SESSIONS.tmp" ]; then
  echo '{"sessions":[],"last_updated":"'"$NOW"'"}' > "$OUT_SESSIONS"
  echo '{"daily":[],"last_updated":"'"$NOW"'"}' > "$OUT_DAILY"
  echo "No Pi session data found"
  rm -f "$OUT_SESSIONS.tmp"
  exit 0
fi

python3 /dev/stdin "$OUT_SESSIONS.tmp" "$OUT_SESSIONS" "$OUT_DAILY" "$NOW" <<'PYEOF' || true
import json, sys

tmpfile = sys.argv[1]
sessfile = sys.argv[2]
dailyfile = sys.argv[3]
now = sys.argv[4]

with open(tmpfile) as f:
    sessions = [json.loads(line) for line in f if line.strip()]

output = {'sessions': sessions, 'last_updated': now}
with open(sessfile, 'w') as f:
    json.dump(output, f, indent=2)

daily = {}
for s in sessions:
    ts = s.get('started_at', '')
    if ts:
        date = ts[:10]
        if date not in daily:
            daily[date] = {'date': date, 'tokens_in': 0, 'tokens_out': 0, 'cost': 0.0, 'sessions': 0}
        daily[date]['tokens_in'] += s['tokens_in']
        daily[date]['tokens_out'] += s['tokens_out']
        daily[date]['cost'] += s['cost']
        daily[date]['sessions'] += 1

daily_list = sorted(daily.values(), key=lambda d: d['date'], reverse=True)
for d in daily_list:
    d['cost'] = round(d['cost'], 6)

daily_output = {'daily': daily_list, 'last_updated': now}
with open(dailyfile, 'w') as f:
    json.dump(daily_output, f, indent=2)

print(f'Parsed {len(sessions)} sessions, {len(daily_list)} days')
PYEOF

rm -f "$OUT_SESSIONS.tmp"
