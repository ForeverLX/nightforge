#!/usr/bin/env bash
set -euo pipefail

# Token tracker — reads Hermes state.db SQLite, outputs aggregated JSON.
# Run: scripts/harness/token-tracker.sh
# Output: data/tokens/current.json

DB="$HOME/.hermes/profiles/cr1ms0n/state.db"
OUT="$HOME/Github/nightforge/data/tokens/current.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DAYS=30

if [ ! -f "$DB" ]; then
  echo '{"error":"state.db not found","last_updated":"'"$NOW"'"}' > "$OUT"
  exit 1
fi

# Per-model rollup (last N days)
PER_MODEL=$(sqlite3 -json "$DB" "
  SELECT
    s.model,
    COALESCE(SUM(sm.input_tokens), SUM(s.input_tokens)) AS tokens_in,
    COALESCE(SUM(sm.output_tokens), SUM(s.output_tokens)) AS tokens_out,
    COALESCE(SUM(sm.cache_read_tokens), SUM(s.cache_read_tokens)) AS cache_read,
    COALESCE(SUM(sm.cache_write_tokens), SUM(s.cache_write_tokens)) AS cache_write,
    COALESCE(SUM(sm.reasoning_tokens), SUM(s.reasoning_tokens)) AS reasoning,
    COALESCE(SUM(sm.estimated_cost_usd), SUM(s.estimated_cost_usd)) AS cost_usd,
    COUNT(DISTINCT s.id) AS sessions,
    COALESCE(sm.billing_provider, s.billing_provider) AS provider
  FROM sessions s
  LEFT JOIN session_model_usage sm ON sm.session_id = s.id
  WHERE s.started_at > unixepoch('now', '-$DAYS days')
    AND (s.input_tokens > 0 OR sm.input_tokens > 0)
  GROUP BY s.model
  ORDER BY tokens_in DESC;
")

# Daily rollup
DAILY=$(sqlite3 -json "$DB" "
  SELECT
    date(s.started_at, 'unixepoch') AS date,
    COALESCE(SUM(sm.input_tokens), SUM(s.input_tokens)) AS tokens_in,
    COALESCE(SUM(sm.output_tokens), SUM(s.output_tokens)) AS tokens_out,
    COALESCE(SUM(sm.estimated_cost_usd), SUM(s.estimated_cost_usd)) AS cost_usd,
    COUNT(DISTINCT s.id) AS sessions
  FROM sessions s
  LEFT JOIN session_model_usage sm ON sm.session_id = s.id
  WHERE s.started_at > unixepoch('now', '-$DAYS days')
    AND (s.input_tokens > 0 OR sm.input_tokens > 0)
  GROUP BY date(s.started_at, 'unixepoch')
  ORDER BY date DESC;
")

# Totals
TOTALS=$(sqlite3 -json "$DB" "
  SELECT
    COALESCE(SUM(sm.input_tokens), SUM(s.input_tokens)) AS total_tokens_in,
    COALESCE(SUM(sm.output_tokens), SUM(s.output_tokens)) AS total_tokens_out,
    COALESCE(SUM(sm.estimated_cost_usd), SUM(s.estimated_cost_usd)) AS total_cost_usd,
    COUNT(DISTINCT s.id) AS total_sessions
  FROM sessions s
  LEFT JOIN session_model_usage sm ON sm.session_id = s.id
  WHERE s.started_at > unixepoch('now', '-$DAYS days')
    AND (s.input_tokens > 0 OR sm.input_tokens > 0);
")

# Combine into final JSON
python3 -c "
import json

per_model = json.loads('''$PER_MODEL''') if '''$PER_MODEL'''.strip() else []
daily = json.loads('''$DAILY''') if '''$DAILY'''.strip() else []
totals = json.loads('''$TOTALS''') if '''$TOTALS'''.strip() else []

output = {
    'last_updated': '$NOW',
    'period_days': $DAYS,
    'totals': totals[0] if totals else {
        'total_tokens_in': 0, 'total_tokens_out': 0,
        'total_cost_usd': 0.0, 'total_sessions': 0
    },
    'per_model': per_model,
    'daily': daily
}

# Ensure numeric precision
if 'total_cost_usd' in output['totals']:
    output['totals']['total_cost_usd'] = round(float(output['totals']['total_cost_usd']), 6)

for m in output['per_model']:
    m['cost_usd'] = round(float(m.get('cost_usd', 0)), 6)
    m['tokens_in'] = int(m.get('tokens_in', 0))
    m['tokens_out'] = int(m.get('tokens_out', 0))

for d in output['daily']:
    d['cost_usd'] = round(float(d.get('cost_usd', 0)), 6)

with open('$OUT', 'w') as f:
    json.dump(output, f, indent=2)
    f.write('\n')

print(f'Written {len(per_model)} models, {len(daily)} days to $OUT')
"
