#!/usr/bin/env bash
set -euo pipefail

# Token tracker — aggregates token/cost data across all Hermes agent profiles.
# Run: scripts/harness/token-tracker.sh
# Output: data/tokens/current.json
#
# Reads every ~/.hermes/profiles/<name>/state.db (cr1ms0n, omp, local, ...)
# and merges per-model / per-day / total rollups. Previously only the
# cr1ms0n profile was read, silently dropping omp/local (Bonsai-27B, Qwen3.5)
# sessions from the dashboard.

OUT="$HOME/Github/nightforge/data/tokens/current.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DAYS=30
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PER_MODEL_ALL="$TMPDIR/per_model.jsonl"
DAILY_ALL="$TMPDIR/daily.jsonl"
TOTALS_ALL="$TMPDIR/totals.jsonl"
: > "$PER_MODEL_ALL"
: > "$DAILY_ALL"
: > "$TOTALS_ALL"

# sqlite3 -json pretty-prints one multi-line JSON array per query, so each
# profile's output lands in its own file and Python loads whole files.
FOUND_DB=0
i=0
for DB in "$HOME"/.hermes/profiles/*/state.db; do
  [ -f "$DB" ] || continue
  FOUND_DB=1
  i=$((i + 1))
  PM="$TMPDIR/pm.$i.json"
  DY="$TMPDIR/dy.$i.json"
  TT="$TMPDIR/tt.$i.json"

  # Per-model rollup (last N days)
  sqlite3 -json "$DB" "
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
  " > "$PM" 2>/dev/null || true

  # Daily rollup
  sqlite3 -json "$DB" "
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
  " > "$DY" 2>/dev/null || true

  # Totals
  sqlite3 -json "$DB" "
    SELECT
      COALESCE(SUM(sm.input_tokens), SUM(s.input_tokens)) AS total_tokens_in,
      COALESCE(SUM(sm.output_tokens), SUM(s.output_tokens)) AS total_tokens_out,
      COALESCE(SUM(sm.estimated_cost_usd), SUM(s.estimated_cost_usd)) AS total_cost_usd,
      COUNT(DISTINCT s.id) AS total_sessions
    FROM sessions s
    LEFT JOIN session_model_usage sm ON sm.session_id = s.id
    WHERE s.started_at > unixepoch('now', '-$DAYS days')
      AND (s.input_tokens > 0 OR sm.input_tokens > 0);
  " > "$TT" 2>/dev/null || true

  cat "$PM" >> "$PER_MODEL_ALL"
  cat "$DY" >> "$DAILY_ALL"
  cat "$TT" >> "$TOTALS_ALL"
done

if [ "$FOUND_DB" -eq 0 ]; then
  echo "No Hermes profile state.db found under ~/.hermes/profiles/" >&2
  exit 1
fi

# Merge across profiles in Python
python3 - "$TMPDIR" "$OUT" "$NOW" "$DAYS" <<'PYEOF'
import json, glob, sys

tmpdir, out, now, days = sys.argv[1:]

def load_rows(pattern):
    rows = []
    for path in sorted(glob.glob(pattern)):
        try:
            with open(path) as f:
                v = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            continue
        if isinstance(v, list):
            rows.extend(v)
        elif isinstance(v, dict):
            rows.append(v)
    return rows

per_model = load_rows(f"{tmpdir}/pm.*.json")
daily = load_rows(f"{tmpdir}/dy.*.json")
totals = load_rows(f"{tmpdir}/tt.*.json")

# Merge per-model: sum numerics, keep provider of the row with most sessions
merged = {}
for m in per_model:
    key = m.get('model')
    if not key:
        continue
    cur = merged.setdefault(key, {
        'model': key, 'tokens_in': 0, 'tokens_out': 0, 'cache_read': 0,
        'cache_write': 0, 'reasoning': 0, 'cost_usd': 0.0,
        'sessions': 0, 'provider': None, '_top_sessions': 0,
    })
    for field in ('tokens_in', 'tokens_out', 'cache_read', 'cache_write', 'reasoning'):
        cur[field] += int(m.get(field, 0) or 0)
    cur['cost_usd'] += float(m.get('cost_usd', 0) or 0)
    cur['sessions'] += int(m.get('sessions', 0) or 0)
    prov = m.get('provider')
    if prov and int(m.get('sessions', 0) or 0) >= cur['_top_sessions']:
        cur['provider'] = prov
        cur['_top_sessions'] = int(m.get('sessions', 0) or 0)

per_model_out = []
for key in sorted(merged, key=lambda k: merged[k]['tokens_in'], reverse=True):
    m = merged[key]
    per_model_out.append({
        'model': m['model'],
        'tokens_in': m['tokens_in'],
        'tokens_out': m['tokens_out'],
        'cache_read': m['cache_read'],
        'cache_write': m['cache_write'],
        'reasoning': m['reasoning'],
        'cost_usd': round(m['cost_usd'], 6),
        'sessions': m['sessions'],
        'provider': m['provider'],
    })

# Merge daily
merged_daily = {}
for d in daily:
    key = d.get('date')
    if not key:
        continue
    cur = merged_daily.setdefault(key, {'date': key, 'tokens_in': 0, 'tokens_out': 0, 'cost_usd': 0.0, 'sessions': 0})
    cur['tokens_in'] += int(d.get('tokens_in', 0) or 0)
    cur['tokens_out'] += int(d.get('tokens_out', 0) or 0)
    cur['cost_usd'] += float(d.get('cost_usd', 0) or 0)
    cur['sessions'] += int(d.get('sessions', 0) or 0)

daily_out = []
for key in sorted(merged_daily, reverse=True):
    d = merged_daily[key]
    daily_out.append({k: d[k] for k in ('date', 'tokens_in', 'tokens_out', 'cost_usd', 'sessions')})
    daily_out[-1]['cost_usd'] = round(daily_out[-1]['cost_usd'], 6)

# Merge totals
t = {'total_tokens_in': 0, 'total_tokens_out': 0, 'total_cost_usd': 0.0, 'total_sessions': 0}
for row in totals:
    t['total_tokens_in'] += int(row.get('total_tokens_in', 0) or 0)
    t['total_tokens_out'] += int(row.get('total_tokens_out', 0) or 0)
    t['total_cost_usd'] += float(row.get('total_cost_usd', 0) or 0)
    t['total_sessions'] += int(row.get('total_sessions', 0) or 0)
t['total_cost_usd'] = round(t['total_cost_usd'], 6)

output = {
    'last_updated': now,
    'period_days': int(days),
    'totals': t,
    'per_model': per_model_out,
    'daily': daily_out,
}

with open(out, 'w') as f:
    json.dump(output, f, indent=2)
    f.write('\n')

print(f'Written {len(per_model_out)} models, {len(daily_out)} days to {out}')
print(f'Totals: {t["total_sessions"]} sessions, ${t["total_cost_usd"]:.4f}')
PYEOF
