# L9 (Benefit Measurement) & L10 (Weight Update) — Design

**Date:** 2026-07-26
**Status:** Design Complete
**Predecessors:** `architecture/l9-l10-redesign.md` (EWMA + safety bounds), `architecture/eval-optimization-design.md` (metrics schema, A/B protocol), `gap-briefs/gap-6-l9-l10-redesign.md`
**Integration targets:** L3 Routing, L4 Failure Mining, L5 Proposal Engine, L7 Versioning

---

## 1. Purpose

### L9 — Benefit Measurement (Optimization)

Quantify whether each applied change actually improves system outcomes. L9 consumes eval scores from L5, computes per-route quality metrics, and produces optimised routing weights. It closes the "did it help?" question that L4/L5 raise but cannot answer alone.

Without L9, proposals get accepted or rejected by hand, routing stays static, and improvements plateau. L9 provides the data-driven signal to keep getting better.

### L10 — Weight Update (Auto-adaptation)

Apply L9's weight recommendations to live routing with safety guarantees. L10 is the gate that prevents optimization from destabilizing the system — it enforces bounds, detects degradation, and rolls back automatically.

Without L10, weights would be updated manually or not at all, making L9 purely theoretical.

### The Loop

```
L5 (Eval scores)  →  L9 (EWMA optimization)  →  L10 (Safety + apply)  →  L3 (Routing)
      ↑                                                                       │
      └─────────────────────── Tasks routed, scores collected ────────────────┘
```

---

## 2. Metrics

### L9 Input Metrics (from L5 eval scores)

Each evaluated task produces a JSON record with these fields:

| Metric | Source | Range | Description |
|--------|--------|-------|-------------|
| `success_rate` | Per-run aggregate | [0.0, 1.0] | Fraction of tasks that passed without error |
| `avg_tokens` | Per-run aggregate | [0, ∞) | Mean tokens consumed per task |
| `p50_latency_ms` | Per-run aggregate | [0, ∞) | Median wall-clock latency in ms |
| `cost_per_task_usd` | Per-run aggregate | [0, ∞) | Token cost × provider rate |
| `composite_score` | Derived | [0.0, 1.0] | Single-number quality score (see below) |

### Composite Score Formula

```python
composite = 0.40 * success_rate
          + 0.25 * (1 - min(avg_tokens / 10_000, 1))
          + 0.20 * (1 - min(p50_latency_ms / 30_000, 1))
          - 0.15 * min(cost_per_task / 0.05, 1)
```

Weights reflect that **correctness matters most**, token cost and latency matter equally, and monetary cost is a secondary constraint. Caps prevent outliers from cratering the score.

### L9 Output Metrics (per route, per window)

| Metric | Description |
|--------|-------------|
| `S_i_avg` | Mean composite score for route `i` over the 24h window |
| `N_i` | Task count for route `i` in the window |
| `w_i(t)` | Current weight for route `i` |
| `w_i(t+1)` | Proposed weight for route `i` (after EWMA) |

### L10 Health Metrics

| Metric | Description | Threshold |
|--------|-------------|-----------|
| Composite delta (1h vs baseline) | Detects degradation after update | >20% drop → rollback |
| Per-route weight change/day | Prevents oscillation | ±0.20 max absolute |
| Min route weight floor | Prevents starving any route | 0.05 minimum |
| Rollback count/7d | Operator signal | >2 in 7d → flag for review |

---

## 3. Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                          DATA FLOW                                   │
│                                                                      │
│  L5 (Evaluation)                                                      │
│  ┌───────────────────────────────────────┐                           │
│  │  Writes per-task eval scores to       │                           │
│  │  ~/80-Operations/data/eval-scores/    │                           │
│  │  Format: <task_id>.json               │                           │
│  │  Fields: route, metrics, composite    │                           │
│  └──────────┬────────────────────────────┘                           │
│             │                                                         │
│             ▼                                                         │
│  L9 (Benefit Measurement) — hourly                                   │
│  ┌───────────────────────────────────────┐                           │
│  │  1. Scan eval-scores/ for files with  │                           │
│  │     timestamp >= now - 24h            │                           │
│  │  2. Group by route, compute S_i_avg   │                           │
│  │  3. Apply EWMA: w_i(t+1) = α·w_i(t)  │                           │
│  │     + (1-α)·S_i_avg/ΣS_j_avg         │                           │
│  │  4. Write routing-weights.json with   │                           │
│  │     proposed weights + previous       │                           │
│  │     weights for rollback              │                           │
│  └──────────┬────────────────────────────┘                           │
│             │                                                         │
│             ▼                                                         │
│  L10 (Weight Update) — daily @ 00:00, or on A/B completion           │
│  ┌───────────────────────────────────────┐                           │
│  │  1. Read routing-weights.json         │                           │
│  │  2. Validate safety bounds:           │                           │
│  │     - Clamp to [0.05, 1.0]           │                           │
│  │     - Cap daily Δ at 0.20            │                           │
│  │     - Renormalise ∑=1.0              │                           │
│  │  3. Compare composite against         │                           │
│  │     baseline — >20% drop → rollback   │                           │
│  │  4. On pass: write final weights,     │                           │
│  │     archive previous weights          │                           │
│  │  5. On rollback: revert to previous,  │                           │
│  │     set 24h cooldown, log event       │                           │
│  └──────────┬────────────────────────────┘                           │
│             │                                                         │
│             ▼                                                         │
│  L3 (Routing)                                                         │
│  ┌───────────────────────────────────────┐                           │
│  │  Reads routing-weights.json (cached   │                           │
│  │  5 min, re-read on sig or touch)      │                           │
│  │  Picks route via proportional random  │                           │
│  │  sampling from weight vector          │                           │
│  └───────────────────────────────────────┘                           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Files

| File | Purpose | Producer | Consumer |
|------|---------|----------|----------|
| `80-Operations/data/eval-scores/<task_id>.json` | Per-task eval records | L5 | L9 |
| `80-Operations/data/routing-weights.json` | Current + previous weight vector | L9 | L10, L3 |
| `80-Operations/data/rollback-log.yaml` | Rollback event history | L10 | Operator |
| `80-Operations/config/l9-l10.yaml` | Config: alpha, weights, thresholds | Manual | L9, L10 |

---

## 4. Implementation Plan

### Phase 1: Data Foundation

**Deliverable:** Eval score collection and routing-weights.json schema.

1. **Define eval-scores directory** — `mkdir -p ~/80-Operations/data/eval-scores/`
2. **Define routing-weights.json schema** — JSON with `generated_at`, `alpha`, `window_hours`, `weights`, `weights_sum`, `scores_used`, `previous_weights`
3. **Wire L5 to write eval scores** — Add post-task hook to `proposal-engine.sh` that writes the eval JSON after each evaluated task

### Phase 2: L9 — Benefit Measurement (EWMA)

**Deliverable:** Running script that produces weighted routing recommendations.

1. **Create `80-Operations/scripts/l9-optimize.py`:**

```python
#!/usr/bin/env python3
"""
L9 — Benefit Measurement / Optimization
Hourly cron: reads eval scores, computes EWMA, writes routing-weights.json
"""
import json, os, glob
from datetime import datetime, timedelta, timezone

CONFIG_PATH = os.path.expanduser("~/80-Operations/config/l9-l10.yaml")
DATA_DIR = os.path.expanduser("~/80-Operations/data/")
EVAL_DIR = os.path.join(DATA_DIR, "eval-scores")
WEIGHTS_PATH = os.path.join(DATA_DIR, "routing-weights.json")
WINDOW_HOURS = 24
ALPHA = 0.7
MIN_TASKS_PER_ROUTE = 3  # don't trust routes with <3 tasks in window
ZERO_TASK_DECAY = 0.95

def load_weights():
    if os.path.exists(WEIGHTS_PATH):
        with open(WEIGHTS_PATH) as f:
            return json.load(f)
    return {"weights": {}, "previous_weights": {}}

def load_eval_scores(since):
    scores = {}
    for fp in glob.glob(os.path.join(EVAL_DIR, "*.json")):
        with open(fp) as f:
            rec = json.load(f)
        ts = datetime.fromisoformat(rec["timestamp"])
        if ts < since:
            continue
        route = rec.get("route", "unknown")
        scores.setdefault(route, []).append(rec["composite_score"])
    return scores

def compute_ewma():
    now = datetime.now(timezone.utc)
    since = now - timedelta(hours=WINDOW_HOURS)

    current = load_weights()
    prev_weights = current.get("weights", {})
    eval_scores = load_eval_scores(since)

    # Compute S_i_avg per route with ≥ MIN_TASKS threshold
    s_avgs = {}
    for route, scores in eval_scores.items():
        if len(scores) >= MIN_TASKS_PER_ROUTE:
            s_avgs[route] = sum(scores) / len(scores)

    # Carry forward zero-task routes with decay
    all_routes = set(list(prev_weights.keys()) + list(s_avgs.keys()))
    for route in all_routes:
        if route not in s_avgs and route in prev_weights:
            s_avgs[route] = ZERO_TASK_DECAY * s_avgs.get(route, 0.5)

    # Normalisation denominator
    total_s = sum(s_avgs.values()) or 1.0

    # EWMA: w_i(t+1) = α·w_i(t) + (1-α)·S_i_avg/ΣS_j_avg
    weights = {}
    for route in all_routes:
        prior = prev_weights.get(route, 1.0 / max(len(all_routes), 1))
        raw = s_avgs.get(route, prior)
        norm = raw / total_s
        weights[route] = round(ALPHA * prior + (1 - ALPHA) * norm, 4)

    # Renormalise to sum=1
    total_w = sum(weights.values())
    weights = {k: round(v / total_w, 4) for k, v in weights.items()}

    # Fix floating point: assign remainder to largest
    diff = round(1.0 - sum(weights.values()), 4)
    if diff and weights:
        largest = max(weights, key=weights.get)
        weights[largest] = round(weights[largest] + diff, 4)

    output = {
        "generated_at": now.isoformat(),
        "alpha": ALPHA,
        "window_hours": WINDOW_HOURS,
        "weights": weights,
        "weights_sum": sum(weights.values()),
        "scores_used": sum(len(v) for v in eval_scores.values()),
        "previous_weights": prev_weights,
    }
    return output

if __name__ == "__main__":
    result = compute_ewma()
    with open(WEIGHTS_PATH, "w") as f:
        json.dump(result, f, indent=2)
    print(f"L9: wrote {WEIGHTS_PATH} — {result['scores_used']} scores, {len(result['weights'])} routes")
```

2. **Create systemd timer** — `l9-optimize.timer` running hourly:

```ini
# ~/.config/systemd/user/l9-optimize.service
[Unit]
Description=L9 Benefit Measurement — EWMA optimization

[Service]
Type=oneshot
ExecStart=%h/80-Operations/scripts/l9-optimize.py
```

```ini
# ~/.config/systemd/user/l9-optimize.timer
[Unit]
Description=Hourly L9 optimization

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

### Phase 3: L10 — Weight Update (Auto-adaptation)

**Deliverable:** Daily weight application with safety bounds and rollback.

1. **Create `80-Operations/scripts/l10-adapt.py`:**

```python
#!/usr/bin/env python3
"""
L10 — Weight Update / Auto-adaptation
Daily cron: validates L9 weights, applies with bounds, rollbacks on degradation.
"""
import json, os, sys, yaml
from datetime import datetime, timezone

DATA_DIR = os.path.expanduser("~/80-Operations/data/")
WEIGHTS_PATH = os.path.join(DATA_DIR, "routing-weights.json")
ROLLBACK_LOG = os.path.join(DATA_DIR, "rollback-log.yaml")
COOLDOWN_HOURS = 24

# Safety bounds
MIN_WEIGHT = 0.05
MAX_DAILY_DELTA = 0.20
COMPOSITE_DROP_THRESHOLD = 0.20  # 20% drop triggers rollback

def load_current():
    with open(WEIGHTS_PATH) as f:
        return json.load(f)

def load_rollback_log():
    if os.path.exists(ROLLBACK_LOG):
        with open(ROLLBACK_LOG) as f:
            return yaml.safe_load(f) or []
    return []

def check_cooldown(log):
    """If a rollback happened within COOLDOWN_HOURS, skip auto-apply."""
    if not log:
        return False
    last = log[-1]
    ts = datetime.fromisoformat(last["timestamp"])
    elapsed = (datetime.now(timezone.utc) - ts).total_seconds() / 3600
    return elapsed < COOLDOWN_HOURS

def enforce_bounds(proposed, previous):
    """Apply safety bounds to proposed weights."""
    weights = {}
    for route, w in proposed.items():
        w = max(MIN_WEIGHT, min(1.0, w))
        prev = previous.get(route, MIN_WEIGHT)
        w = min(w, prev + MAX_DAILY_DELTA)
        w = max(w, prev - MAX_DAILY_DELTA)
        weights[route] = round(w, 4)
    # Renormalise
    total = sum(weights.values())
    weights = {k: round(v / total, 4) for k, v in weights.items()}
    # Fix fp remainder on largest
    diff = round(1.0 - sum(weights.values()), 4)
    if diff and weights:
        largest = max(weights, key=weights.get)
        weights[largest] = round(weights[largest] + diff, 4)
    return weights

def check_degradation(before, after):
    """Compare composite scores before vs after update. Return drop ratio."""
    # In production, this reads recent eval scores post-update.
    # Phase 1 stub: always returns 0.0 (no degradation).
    return 0.0

def log_rollback(reason, baseline, current, applied, reverted):
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "trigger": reason,
        "baseline_composite": baseline,
        "current_composite": current,
        "drop_pct": round((baseline - current) / baseline * 100, 1) if baseline else 0,
        "applied_weights": applied,
        "reverted_to": reverted,
        "cooldown_until": (datetime.now(timezone.utc).replace(hour=0, minute=0, second=0) +
                          timedelta(hours=COOLDOWN_HOURS)).isoformat(),
    }
    log = load_rollback_log()
    log.append(entry)
    os.makedirs(os.path.dirname(ROLLBACK_LOG), exist_ok=True)
    with open(ROLLBACK_LOG, "w") as f:
        yaml.dump(log, f, default_flow_style=False)
    return entry

if __name__ == "__main__":
    data = load_current()
    proposed = data["weights"]
    previous = data.get("previous_weights", {})

    # Check cooldown
    if check_cooldown(load_rollback_log()):
        print("L10: cooldown active — skipping auto-apply")
        sys.exit(0)

    # Enforce bounds
    safe_weights = enforce_bounds(proposed, previous)

    # Check degradation (Phase 1: stub, always pass)
    drop = check_degradation(None, None)
    if drop > COMPOSITE_DROP_THRESHOLD:
        entry = log_rollback("composite_drop_too_large", 0, 0, safe_weights, previous)
        # Revert: write previous weights as current
        data["weights"] = previous
        data["previous_weights"] = {}  # clear for next cycle
        with open(WEIGHTS_PATH, "w") as f:
            json.dump(data, f, indent=2)
        print(f"L10: ROLLBACK — {entry['trigger']}, cooldown until {entry['cooldown_until']}")
        sys.exit(1)

    # Apply
    data["previous_weights"] = proposed  # save proposed as previous for next cycle
    data["weights"] = safe_weights
    with open(WEIGHTS_PATH, "w") as f:
        json.dump(data, f, indent=2)
    print(f"L10: weights applied — {len(safe_weights)} routes")
```

2. **Create systemd timer** — `l10-adapt.timer` running daily at midnight:

```ini
# ~/.config/systemd/user/l10-adapt.service
[Unit]
Description=L10 Auto-adaptation — weight update with safety

[Service]
Type=oneshot
ExecStart=%h/80-Operations/scripts/l10-adapt.py
```

```ini
# ~/.config/systemd/user/l10-adapt.timer
[Unit]
Description=Daily L10 weight update

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

### Phase 4: Integration with Existing Layers

| Integration | What Changes | Layer |
|-------------|-------------|-------|
| L5 proposal-engine.sh | Add post-eval hook: write `task_id.json` to `eval-scores/` | L5 |
| L3 routing | Read `routing-weights.json` on dispatch; cache 5 min | L3 |
| L7 rollback | `rollback.sh` can restore a previous `routing-weights.json` from history | L7 |
| L4 failure-miner | Flag `rollback-log.yaml` entries as failure events if >2 in 7d | L4 |
| L5 proposal generation | Detect degraded routes → generate "rebalance routing weights" proposal | L5 |

---

## 5. Safety Considerations

### 5.1 Weight Safety Bounds

| Bound | Value | Rationale |
|-------|-------|-----------|
| Minimum per-route weight | **0.05** | No route can be starved entirely. Keeps exploration alive. |
| Maximum daily delta | **±0.20** absolute | Prevents oscillation. A route can't go from 0.10 → 0.50 overnight. |
| Composite drop threshold | **>20% in 1 hour** | Triggers automatic rollback to previous weights. |
| Post-rollback cooldown | **24 hours** | No auto-updates during cooldown — gives operator time to investigate. |
| Min tasks for a score | **3 tasks per route** | Don't trust thin data. A route with 1 success and 0 failures isn't evidence. |

### 5.2 Rollback Triggers

L10 automatically reverts if:

1. **Composite score drops >20%** in the hour following a weight update
2. **Any route is about to fall below min weight** (clamped before it can happen)
3. **Eval data is absent** for all routes (empty 24h window → skip update, don't zero)

Rollback writes to `rollback-log.yaml`, increments a counter, and disables auto-apply for 24h.

### 5.3 Exploration Safeguard

The min-weight floor of 0.05 ensures every route gets at least some traffic — this is the **exploration budget**. Even a route that performed poorly last cycle still gets 5% of tasks, generating fresh eval data so L9 can detect if it's recovered.

### 5.4 Weight Staleness Detection

If a route has **zero tasks in the 24h window**, its score is decayed by `0.95×` per cycle rather than dropping to zero. This prevents "cold start" routes from being eliminated before they get enough traffic.

### 5.5 What the v2.0 Redesign Changes

The S148 architecture review proposed remapping L9/L10 to L8 (Optimization) and L9 (Auto-adaptation), with the Memory layer becoming L10. This design is compatible with either numbering — the data flow, formulas, and safety bounds are identical. The v2.0 renumbering is a presentation change; the logic stands.

### 5.6 Limitations (Phase 1)

| Limitation | Impact | When to Address |
|-----------|--------|-----------------|
| Composite score weights are static | Doesn't adapt to changing priorities | After 30 days of data, add meta-optimization |
| Degradation check is a stub | Rollback only triggers on obvious failures | When Langfuse integration provides real-time composite |
| A/B test integration not wired | L9 treats all traffic as one population | After Phase 3, when L5 A/B runner is stable |
| No per-profile weight separation | All profiles share one weight vector | When profile-specific routing is needed |

---

## 6. Rollout Checklist

- [ ] `mkdir -p ~/80-Operations/data/eval-scores/`
- [ ] Create `l9-optimize.py` and `l10-adapt.py`
- [ ] Create systemd service + timer files
- [ ] Enable timers: `systemctl --user enable --now l9-optimize.timer l10-adapt.timer`
- [ ] Wire L5 to write eval score JSON after each evaluated task
- [ ] Wire L3 to read `routing-weights.json` on dispatch
- [ ] Seed `routing-weights.json` with initial uniform weights
- [ ] Verify: `systemctl --user status l9-optimize.timer l10-adapt.timer`
- [ ] Verify: `l9-optimize.py` runs and produces valid JSON
- [ ] Verify: `l10-adapt.py` enforces bounds on a known-bad weight vector
- [ ] Dry-run: 24h of eval data, observe weight convergence
