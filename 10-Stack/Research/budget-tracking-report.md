---
title: AI API Spend Tracking — Research Report
created: 2026-07-19
status: active
tags: [budget, ops, tracking, openrouter, ocg, omp]
---

# AI API Spend Tracking Research Report

## Context

Goal: $25-30/mo total AI API spend, with OCG (OpenCode Go) at $10/mo locked.
Need real-time usage tracking (not estimates) across OpenRouter, OpenCode Go/Zen, and local models.

## Data Sources Evaluated

### 1. OpenRouter API (`/api/v1/auth/key`) — ✅ Works

**Endpoint:** `GET https://openrouter.ai/api/v1/auth/key`
**Auth:** Bearer token (existing `OPENROUTER_API_KEY`)

Returns per-key bucket data:

| Field | Value (current) | Notes |
|-------|----------------|-------|
| `limit` | 20 | Monthly budget cap in USD |
| `limit_remaining` | 16.73 | Remaining this month |
| `usage` | 5.18 | Lifetime total USD |
| `usage_monthly` | 3.27 | Current month |
| `usage_daily` | 0.0003 | Today |
| `expires_at` | 2027-06-20 | Key expiry |

**Limitations:** Aggregated only — no per-request breakdown. No generation history endpoint for regular API keys (management key required for activity logs, which we don't have).

### 2. OpenRouter Chat Completions Response — ✅ Granular

Every `POST /v1/chat/completions` response includes:

```json
{
  "id": "gen-1784523588-cnAEuzNruvzB0CNcF8tl",
  "model": "meta/muse-spark-1.1",
  "usage": {
    "prompt_tokens": 166,
    "completion_tokens": 20,
    "total_tokens": 186,
    "cost": 0.0002925,
    "cost_details": {
      "upstream_inference_cost": 0.0002925,
      "upstream_inference_prompt_cost": 0.0002075,
      "upstream_inference_completions_cost": 8.5e-05
    }
  }
}
```

**Key:** `usage.cost` is exact dollar amount. This is the most reliable per-request source.

### 3. OpenRouter Models API (`/api/v1/models`) — ✅ Pricing Reference

Returns per-model pricing:
- `pricing.prompt` — per-token prompt cost
- `pricing.completion` — per-token completion cost
- `pricing.input_cache_read` — cached token discount

Useful for estimating costs from token counts when the API doesn't return cost directly.

### 4. OpenCode Go API — ❌ No Usage Endpoint

- `/v1/models` — works (returns model list)
- `/v1/auth/key` — not a valid endpoint
- `/v1/credits` — not a valid endpoint
- `/v1/usage` — not a valid endpoint
- No usage/credits/limits API discovered

OpenCode Go/Zen returns cost data only in the chat completions response body.

### 5. OpenCode Zen API — ❌ Same Situation

Same as OCG — standard OpenAI-compatible completions API, no usage/credits endpoint.
Models accessible: claude-fable-5, claude-opus-4-8, claude-opus-4-7, big-pickle, etc.

### 6. OMP `agent.db` — ✅ Already Tracking (Partial)

Tables discovered:

| Table | Rows | Data |
|-------|------|------|
| `usage_cost_history` | 3,393 | Per-request: provider, recorded_at, cost_usd |
| `usage_history` | 408 | Aggregate windows: 5hr, weekly, monthly |
| `model_usage` | 16 | Model keys + last_used_at timestamps |

**Current tracked provider:** `opencode-go` only — $16.27 total (Jun 20 – Jul 19).
**Not tracked:** OpenRouter costs are missing from this table even though the session files contain full cost data.

**Config:** `display.showTokenUsage: true` — OMP already renders token counts in its TUI.

### 7. OMP Session JSONL Files — ✅ Full Per-Request Data

Stored at `~/.omp/agent/sessions/-tmp/<session_id>.jsonl`

Each assistant message contains:
- `model` (e.g., `deepseek-v4-flash`, `kimi-k2.7-code`)
- `provider` (`opencode-go`, `openrouter`)
- `usage.input`, `usage.output`, `usage.cacheRead`, `usage.cacheWrite` — token counts
- `usage.cost.input`, `usage.cost.output`, `usage.cost.total` — exact dollar amounts
- `timestamp`, `duration`, `ttft` — performance metrics

Both `opencode-go` and `openrouter` sessions have complete data here.

### 8. Hermes Request Dumps — ❌ Barely Useful

`~/.hermes/sessions/` only captures failed request dumps (auth errors, non-retryable failures).
No successful response recording for cost analysis.

### 9. Local LLM (llama.cpp) — ✅ Free

Ornith-1.0-35B / Bonsai-27B running on localhost:8081/v1.
No cost to track. Free tier provides unlimited local inference within hardware limits (RTX 3070 8GB).

### 10. OpenRouter Dashboard — Manual Option

Web dashboard at openrouter.ai/activity shows per-generation usage with model, tokens, cost.
No CSV export found. Manual copy-paste would be tedious.

## Current State Summary

| Provider | Per-Request Cost in OMP DB | In Session JSONL | Real-Time API |
|----------|---------------------------|-------------------|---------------|
| OpenCode Go | ✅ Yes (3,393 rows) | ✅ Yes | ❌ No endpoint |
| OpenRouter | ❌ No | ✅ Yes | ✅ Bucket-level |
| Local LLM | N/A (free) | ✅ Yes | N/A |
| OpenGateway | Unknown | Unknown | Unknown |

## Recommended Tracking Approach

**Build a lightweight CLI aggregator script** that polls the two available data sources and stores results in a local SQLite DB (or extends OMP's existing `agent.db`).

### Concrete Steps

1. **Week 1 — MVP (Low effort)**
   - Write a Python/Node.js CLI script `api-budget` that:
     - Polls `openrouter.ai/api/v1/auth/key` → records remaining limit + monthly usage
     - Reads OMP's `usage_cost_history` table for opencode-go actuals
     - Stores results in `~/.omp/agent/agent.db` (adds to `usage_cost_history`) or a dedicated `~/.budget-tracker/budget.db`
     - Also scrapes OpenRouter costs from recent OMP session JSONL files (iterate newest sessions, extract `usage.cost.total` per provider)
   - Run as a cron job or systemd timer every 6 hours
   - Output: `api-budget report` → prints current month spend by provider + remaining budget

2. **Week 2 — Polish (Low effort)**
   - Add budget alerts: if OpenRouter usage >80% of monthly limit, print warning
   - Add OpenCode Go limit tracking via its response header (if any)
   - Optional: integrate with OMP's existing `usage_cost_history` Schema so OpenRouter costs flow into the same table

3. **Future (Medium effort if needed)**
   - TUI dashboard showing real-time spend by model/provider
   - Webhook alerts when approaching budget caps
   - Predict spend based on current burn rate

### Architecture

```
┌──────────────────┐     ┌──────────────────┐
│  OpenRouter API  │     │  OMP agent.db    │
│  /auth/key       │     │  usage_cost_hist │
│  (real-time)     │     │  (historical)    │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         ▼                        ▼
┌─────────────────────────────────────────┐
│  api-budget CLI                         │
│  - polls OpenRouter remaining           │
│  - queries OMP cost_history             │
│  - scrapes recent session JSONLs        │
│  - stores in trackingdb.sqlite          │
│  - prints `api-budget report`           │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│  trackingdb.sqlite                       │
│  (or extends OMP's agent.db)             │
│  Tables: provider_snapshots,             │
│          per_request_costs,              │
│          budget_limits                   │
└─────────────────────────────────────────┘
```

## Implementation Effort Estimate

| Component | Effort | Details |
|-----------|--------|---------|
| CLI script skeleton | Low | ~50 lines, stdlib only (sqlite3 + requests/curl) |
| OpenRouter poller | Low | Single API call, parse JSON, insert row |
| OMP DB reader | Low | Query `usage_cost_history`, sum by provider/month |
| Session JSONL scraper | Low-Medium | Iterate ~10 newest files, extract cost data |
| Budget alerts | Low | Compare current spend vs limit, print warning |
| TUI dashboard | Medium | Requires curses/ncurses or rich library |

**Total MVP: Low effort (~2-3 hours)**
**Total with TUI: Medium (~6-8 hours)**

## What to Build First (MVP Scope)

The MVP is a single CLI script:

**File:** `~/.local/bin/api-budget` (or `~/Tools/ai/api-budget`)
**Language:** Python (stdlib only: sqlite3, json, urllib.request)
**Subcommands:**
- `api-budget snapshot` — polls all data sources, stores in tracking DB
- `api-budget report` — prints formatted monthly spend report
- `api-budget watch` — runs snapshot on a loop (every N minutes) with live updates

**Tracking DB:** `~/.local/share/api-budget/budget.db`
**Tables:**
- `provider_snapshots(recorded_at, provider, remaining, limit, usage, monthly_usage)`
- `per_request_costs(recorded_at, provider, model, cost_usd, tokens_in, tokens_out)` — from session JSONL
- `budget_limits(provider, monthly_cap, alert_threshold)` — seeded from MEMORY.md budget data

**Cron:** `*/360 * * * * api-budget snapshot` (every 6 hours)

**Output example:**
```
$ api-budget report
Provider          Month Spend    Limit    Remaining
──────────────────────────────────────────────────
OpenRouter        $3.27          $20.00   $16.73
OpenCode Go       $16.27         $10.00   OVER BUDGET!
Local LLM         $0.00          Free     OK
──────────────────────────────────────────────────
Total this month: $19.54 / $30.00 (65%)
Projected (30d):  $24.43
```

## Key Decisions

1. **Use OMP's existing `agent.db` where possible** — extend `usage_cost_history` with OpenRouter rows rather than creating a parallel DB. This avoids data fragmentation.
2. **Backfill OpenRouter costs from session JSONL files** — iterate the newest sessions and extract `usage.cost.total` + model + provider for each assistant message, then INSERT into `usage_cost_history`.
3. **Poll OpenRouter API for real-time remaining** — the `/auth/key` endpoint is free, fast, and gives current bucket state.
4. **No need for Hermes-level hooks** — OMP already captures the data. Additional hooks would duplicate effort.
5. **Local LLM tracking is optional** — no cost, but tracking usage volume could be useful for capacity planning.

## Related Vault Docs

- `40-Memory/Research/model-pricing-intelligence-report.md` — Budget analysis ($25-30 goal, OCG $10/mo locked)
- `20-Tools/hivemind/hivemind-config-reference.md` — Hivemind hooks (not needed for this)
- `80-Operations/Handoffs/s-series/azrael-handoff-S092-openrouter-provider-fix.md` — OpenRouter provider config
- `40-Memory/azrael-decisions.md` — Budget decisions #28-34
