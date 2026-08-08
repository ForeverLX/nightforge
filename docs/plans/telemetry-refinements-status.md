# Telemetry Refinements — Status

Date: 2026-08-04
Branch: `feat/telemetry-refinements`
Scope: harnessd telemetry accuracy, Prometheus integration, data hygiene
Verification: all endpoints smoke-tested post-change; Prometheus scrapes confirmed live.

## 1. Inventory (as-found)

### Data files (`data/`)
| Path | Content | Written by |
|---|---|---|
| `data/cost/pi-costs.json` (~326 KB, 586 sessions) | Per-session token/cost rollup from `~/.omp/agent/sessions/*.jsonl` | `scripts/harness/pi-session-parser.sh` (full rewrite each run — bounded, not accumulating) |
| `data/cost/pi-costs-daily.json` | Daily aggregation of the above | same |
| `data/tokens/current.json` | 30-day per-model / daily / total rollups | `scripts/harness/token-tracker.sh` |
| `data/failures/failures.json` (339 entries) | Mined failure sessions by category | `scripts/harness/failure-miner.sh` (regenerated from pi-costs.json) |
| `data/gates/gates.json`, `data/proposals/proposals.json` | L6 gate evaluations, L5 proposals | `scripts/harness/gate-check.sh`, `proposal-engine.sh` |
| `data/history/health-YYYY-MM-DD.jsonl` | 5-min health snapshots, one file per day (self-rotating) | harnessd collector |

Hygiene verdict: derived files are rewritten wholesale, not appended — no unbounded growth.
Only `data/history/` accumulates, and it rotates by calendar day. No pruning needed now.

### harnessd (Go, `127.0.0.1:9191`)
- Zero-dependency stdlib module (`go.mod` has no requires).
- API: `/api/v1/{health,layers,sessions,snapshots,routes,cost}` + embedded frontend
  (tabs: L4 Health, L5 Proposals, L6 Gates, L7 Snapshots, L8 Routes, Cost/Tokens).
- Collector samples every 5 min: mem/load via `/proc` (worked), disk via `df`,
  GPU via `nvidia-smi` (both **broken in the deployed service** — see below).

### Observability stack (`10-layer-stack/observability-stack/`, running)
- Docker compose: prometheus (`127.0.0.2:31745`, host net), grafana (`127.0.0.1:31746`),
  node-exporter (`127.0.0.1:31750`), otel-collector (`127.0.0.1:31744`), langfuse (`127.0.0.1:31747`).
- Prometheus scraped `agentgateway` (up) and `node` (up). **No source for `harness_*`
  metrics** — the Grafana "four-agent-architecture" dashboard's L5/L6 panels queried
  `harness_proposals_total` etc., which nothing emitted.

## 2. Bugs fixed

### 2a. Disk + GPU collected as zeros in the deployed dashboard
- Root cause 1: harnessd systemd user service runs with a broken `PATH`
  (`Environment=...` contains a literal `%E{PATH}` that systemd never expanded —
  `~/Github/nightforge/harnessd` env dump confirmed). `df` / `nvidia-smi` were not found,
  so disk showed `0`/`"?"` and GPU `0/0` while mem/load (proc-based) worked.
- Root cause 2: `getDiskUsage` did `TrimSuffix("%", ...)` then `strconv.Atoi` on a
  space-padded value (`df` outputs ` 85%`) — Atoi rejects the leading space, so even with
  a working `df` the percentage parsed as 0.
- Fix (`internal/collector/health.go`): new `execLookPath` resolves binaries via
  `LookPath` with `/usr/bin`, `/bin`, `/usr/local/bin` fallbacks; `df`/`nvidia-smi`
  calls use it; disk percent is `TrimSpace`d before parse.
- Verified: after rebuild + `systemctl --user restart harnessd`, health API returns
  `disk_root 85% / 37G used / 6.6G free`, `disk_home 66% / 258G`, GPU `7142 / 8192` MB.

### 2b. Token tracker read only the `cr1ms0n` Hermes profile
- `scripts/harness/token-tracker.sh` queried only `~/.hermes/profiles/cr1ms0n/state.db`,
  silently dropping `omp` (Bonsai-27B, Qwen3.5) and `local` profile sessions.
- Fix: loop over every `~/.hermes/profiles/*/state.db`, run the same three rollups per
  profile (per-model, daily, totals), merge in Python (numeric sums; provider = row with
  most sessions). Output schema unchanged.
- Note: `sqlite3 -json` pretty-prints one multi-line JSON array per query — the first
  implementation assumed one object per line and broke; fixed by loading whole files.
- Verified: totals moved 135 → **153 sessions** (18 from omp/local, all $0 local models),
  18 models aggregated. Dashboard `/api/v1/cost` still 200.

## 3. New capability: harnessd Prometheus endpoint

- New `GET /metrics` on harnessd (`internal/handler/metrics.go`, zero-dep hand-rolled
  text exposition — go.mod stays dependency-free).
- Emits, backed by the existing data files + collector:
  - `harness_proposals_total`, `harness_proposals_success_total`,
    `harness_proposals_failure_total` (L5 panels in the Grafana dashboard light up)
  - `harness_gates_total{gate,status}` (L6)
  - `harness_failures_total{category}` (L4)
  - `harness_sessions_total`, `harness_tokens_total{direction}`, `harness_cost_usd` (L2)
  - `harness_llm_sessions_total{model}` (per-model routing visibility, L8)
  - `harness_health{metric}` (latest snapshot: mem/load/disk/gpu)
  - `agentgateway_requests_total{service="harnessd"}` — HTTP request counter from the
    server middleware, feeds the dashboard's "24h Health History" panel
- `prometheus.yml`: added `harnessd` job targeting `127.0.0.1:9191` (labels
  `service=harnessd, layer=l5`); prometheus container restarted.
- Verified: prometheus targets all **up** (`agentgateway`, `harnessd`, `node`);
  live query `harness_proposals_success_total` returns `3` with
  `job="harnessd" service="harnessd" layer="l5"`.

## 4. Deferred / follow-ups (not in scope here)

- **L8 panels still empty**: Grafana `agentgateway_llm_requests_total{gen_ai_request_model}`
  and `agentgateway_route_failovers_total` are emitted by nothing — the agentgateway
  process (Rust, pid 620438) exports only tokio/config/cgroup metrics. Route-visibility
  data now exists as `harness_llm_sessions_total{model}`; wiring those two panels to it
  is a one-line expr change per panel in `grafana-dashboard.json`, deliberately not done
  here.
- **GPU panel** (`DCGM_FI_DEV_GPU_UTIL`) expects DCGM exporter; harnessd emits
  `harness_health{metric="gpu_mem_mb"}` instead. Add DCGM exporter or repoint the panel.
- **Unit file PATH bug** lives in `~/.config/systemd/user/harnessd.service`
  (outside the repo) — the literal `%E{PATH}` should be replaced with a real PATH or
  removed. The code fix makes the service correct regardless; the unit edit is
  environment config, left to the operator.
- **Langfuse**: otel-collector is up and langfuse accepts OTLP on `127.0.0.1:31744`;
  harnessd has no tracing today. Feeding OTLP traces would need an exporter dependency —
  deferred (zero-dep policy).
- **`data/history/`**: consider a retention policy (e.g. keep 30 days) if disk pressure
  ever appears; currently ~370 KB total, not urgent.

## 5. Files changed

| File | Change |
|---|---|
| `internal/collector/health.go` | `execLookPath` + disk/GPU fixes |
| `internal/handler/metrics.go` | new Prometheus exposition endpoint |
| `internal/server/server.go` | register `/metrics`, request counter |
| `scripts/harness/token-tracker.sh` | multi-profile aggregation |
| `10-layer-stack/observability-stack/prometheus.yml` | harnessd scrape target |

Not staged: `data/` churn (telemetry), `dotfiles/matugen/`, `.gitignore` — unrelated to
this change; left untouched per repo rules.
