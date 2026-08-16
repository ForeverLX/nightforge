# observability-stack

S189 CR1MS0N Four-Agent observability stack. Four tools, one trace path:

```
AgentGateway (LLM gateway) --OTLP/grpc--> otel-collector --otlphttp--> Langfuse (traces/metrics)
                                      \----------> Prometheus (infra + gateway metrics) --> Grafana
```

| Tool | Role | Version | Web |
|---|---|---|---|
| **AgentGateway** | LLM gateway + router; source of traces | 1.4.1 (systemd) | — |
| **otel-collector** | OTLP receive (grpc 4317 + http 4318), forward to Langfuse | 0.129.1 | — |
| **Langfuse** | LLM observability: traces, observations, metrics | 4.6.0 | http://127.0.0.1:31747 |
| **Prometheus** | Scrape agentgateway + node-exporter | 3.5.0 | http://127.0.0.2:31745 |
| **Grafana** | Dashboards over Prometheus | 12.1.1 | http://127.0.0.1:31746 |

Supporting stores for Langfuse: postgres 17, clickhouse 25.12 (events), redis 7
(queue), minio (S3 event/media).

## Ports

| Port | Bind | Service |
|---|---|---|
| 31742 | 127.0.0.1 / `*` | AgentGateway default OpenAI-compatible gateway |
| 31744 | 127.0.0.1 | otel-collector gRPC OTLP (4317 in-container) |
| 4318  | 127.0.0.1 | otel-collector HTTP OTLP (added 2026-08-08) |
| 31745 | 127.0.0.2 | Prometheus web + scrape target |
| 31746 | 127.0.0.1 | Grafana |
| 31747 | 127.0.0.1 | Langfuse web (`/api/public/health`) |
| 31748 | — | AgentGateway admin |
| 31749 | — | AgentGateway readiness |
| 31750 | 127.0.0.1 | node-exporter |

## Trace path (verified end-to-end 2026-08-08)

1. AgentGateway emits OTLP traces with gen-ai semantic attributes
   (`gen_ai.request.model`, `gen_ai.usage.input_tokens`, ...).
2. Config: `~/.config/agentgateway/config.yaml` → `config.tracing.otlpEndpoint:
   http://127.0.0.1:31744`, `otlpProtocol: grpc`, `randomSampling: "1.0"`.
3. otel-collector forwards to `langfuse-web:3000/api/public/otel` with Basic
   auth (`LANGFUSE_AUTH_STRING`) and `x-langfuse-ingestion-version: 4` (real-time
   ingestion; without it v2 API data lags up to 10 min).
4. Langfuse persists to ClickHouse (`default.events_core`, `default.events_full`)
   and serves via the v2 API.

**100% sampling** (`randomSampling: "1.0"`): L9 evaluation needs every trace, not
a random subset. This was the P0 instrumentation gap — the previous `true`
discarded spans. Verified: 2 test chats after the change landed as 2 new
`POST /*` GENERATION observations in `events_core`.

## Agent routing through the gateway (2026-08-08)

Both agent LLM clients now route **all** model traffic through AgentGateway so
every request lands in Prometheus/Grafana/Langfuse. Before this, OMP and Hermes
talked to opencode.ai directly and the stack saw zero real traffic.

| Client | Mechanism | Config |
|---|---|---|
| **Hermes** (cr1ms0n profile) | provider `base_url` → gateway, `api_key_env` → gateway key | `~/.hermes/profiles/cr1ms0n/config.yaml` |
| **OMP** (pi-coding-agent) | `models.yaml` provider override: `baseUrl` + `apiKey` (beats bundled opencode.ai host, priority #1) | `~/.omp/agent/models.yaml` |

Details:

- Gateway endpoint: `http://127.0.0.1:31742/v1`, auth `Bearer agw_sk_...`
  (strict mode; the gateway rejects the opencode keys).
- Gateway proxies upstream to opencode-go (`zen/go/v1`) / opencode-zen
  (`zen/v1`) using its own `${OPENCODE_GO_API_KEY}` / `${OPENCODE_ZEN_API_KEY}`
  (in `~/.config/agentgateway/agentgateway.env`).
- Hermes: `opencode-go`/`opencode-zen` providers + top-level `model.base_url`
  pointed at the gateway; `AGENTGATEWAY_API_KEY` added to `~/.hermes/.env`.
  Config is mtime-cache-invalidated, so running services pick it up; services
  restarted anyway (`buzz-hermes`, `hermes-gateway`, `hermes-gateway-cr1ms0n`).
- OMP: `~/.omp/agent/models.yaml` overrides `opencode-go`/`opencode-zen`
  `baseUrl` + `apiKey` (gateway key, `authHeader: true`). Per-invocation read;
  no restart needed.
- OMP model catalog still lists 50+ opencode models but the gateway exposes the
  11 in `config.yaml` `models:`. OMP's `modelRoles` only use 4 (kimi-k2.7-code,
  deepseek-v4-pro, deepseek-v4-flash, nemotron-3-ultra-free) — all present.
  Models outside the gateway list return `model_not_found`; add them to the
  gateway `models:` block if OMP starts requesting them.
- Upstream usage limits still apply (opencode.ai `GoUsageLimitError` → gateway
  `429`); that is a provider-side throttle, not a gateway issue.

**Verified live (2026-08-08 22:15Z):** `agentgateway_requests_total` shows
big-pickle 143+, nemotron-3-ultra-free 61+, deepseek-v4-flash 26 (real agent
traffic); Grafana datasource proxy returns 0.79 req/s and 82K tok/s over 5m;
Langfuse `agent_traces=83` (was 7 before routing).

## Default vs configured

Read-first review of each tool against its official docs; everything below
originally shipped at default and was made explicit.

| Tool | Was (default) | Now (configured) | Why |
|---|---|---|---|
| AgentGateway | `randomSampling: true` (random fraction) | `randomSampling: "1.0"` (100%) | L9 needs every trace |
| otel-collector | grpc-only on 4317 | + HTTP receiver on 4318 | agents may use `http/protobuf` |
| otel-collector | no auth to Langfuse | Basic auth + `x-langfuse-ingestion-version: 4` | v2 API real-time ingestion |
| Prometheus | default 15d retention, 127.0.0.1:9090 | 180d retention, 127.0.0.2:31745 | retain node_snapshots backfill |
| Prometheus | 2 scrape targets | agentgateway + node (harnessd job removed) | harnessd decommissioned |
| Grafana | placeholder admin password | reset + `.env` synced | security + API access |
| Grafana | dashboard queried nonexistent metrics | corrected PromQL to real metric names | panels were dead |
| Langfuse | — | project `cr1ms0n-harness`, org CR1MS0N | init from `.env` |

### Grafana dashboard corrections (2026-08-08)

The provisioned dashboard (`uid cr1mson-four-agent-s189`) referenced metric
names that **do not exist** in the live agentgateway export, so L4/L5/L8/L9
panels rendered empty. Corrected to real metric names:

| Panel | Was (broken) | Now (real) |
|---|---|---|
| GPU Utilization | `DCGM_FI_DEV_GPU_UTIL` (no exporter) | `agentgateway_process_rss` (Gateway RSS) |
| 24h Health (MCP) | `agentgateway_mcp_requests_total` | `agentgateway_requests_total` by `protocol` |
| Model Routing | `agentgateway_llm_requests_total` | `agentgateway_gen_ai_server_request_duration_count` by `gen_ai_request_model` |
| Route Latency p95 | `agentgateway_llm_request_duration_seconds_bucket` | `agentgateway_gen_ai_server_request_duration_bucket` |
| Latency by Model | `agentgateway_llm_request_duration_seconds_bucket` | `agentgateway_gen_ai_server_request_duration_bucket` |
| Cost per Model | `agentgateway_llm_cost_usd_total` (nonexistent) | `agentgateway_request_processing_seconds_sum/count` (avg processing by route) |

Removed dead panels with **no** Prometheus source: Proposal Status /
Success / Failure (`harness_proposals_*` — L5 metrics live in Langfuse/benefit
data, not Prometheus), Failover Events (`agentgateway_route_failovers_total`
does not exist). These belong in Langfuse native dashboards, not Grafana.

Dashboard is provisioned read-only (`disableDeletion`, `editable: false`); apply
changes by editing `grafana-dashboard.json` then:

```bash
curl -X POST -u admin:$GRAFANA_ADMIN_PASSWORD \
  http://127.0.0.1:31746/api/admin/provisioning/dashboards/reload
```

## Langfuse integration boundary

**Langfuse has no Grafana datasource plugin and no Prometheus business-metrics
endpoint** (langfuse PR #8157 closed — only system metrics, unmerged; confirmed
`/metrics` returns 404 on 4.6.0). Therefore:

- **Grafana** = infra + gateway (Prometheus): node-exporter + agentgateway.
- **Langfuse** = L9 trace metrics (token/cost/latency/agent_traces) via its
  **native custom dashboards** (versioned JSON, API-manageable). L9 `M1-M10`
  metrics are computed by `cmd/l9-benefit-measurement` and written to
  `data/benefit/daily.json`.

## L9 benefit measurement

`cmd/l9-benefit-measurement` (Go) queries Langfuse v2 observations and writes a
verdict to `data/benefit/daily.json`.

**2026-08-08 fix:** the stub read v1 field names (`model`, `input`, `output`,
`total`) that the **v2 Observations API does not return** — v2 uses selective
field groups and names the fields `providedModelName`, `inputUsage`,
`outputUsage`, `totalUsage`. The stub never requested those groups, so it always
saw `agent_traces=0` even with live traces. Fixed by:

1. Struct JSON tags → v2 field names (`providedModelName`, `inputUsage`, ...).
2. Fetch URL → `&fields=core,basic,model,usage,metrics`.

Result: verdict flipped `no_data` → `pending` (4 agent traces detected from the
live gateway tests).

## Services

| Service | Manage | Health |
|---|---|---|
| AgentGateway | `systemctl --user status agentgateway` | `curl 127.0.0.1:31749` |
| Compose stack | `docker compose up -d` in this dir | `docker compose ps` |

## Secrets

All credentials in `.env` (mode 600, gitignored). Do not commit. Rotating any
secret that a service reads only at volume-init time (Postgres, ClickHouse,
MinIO, Grafana) requires either a volume wipe (before first real data) or the
Grafana CLI reset. See TROUBLESHOOTING.md.
