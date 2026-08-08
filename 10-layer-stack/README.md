# 10-Layer Stack

Implementation home for the CR1MS0N self-improving harness architecture (L1–L10).

Source framework: AlphaSignal, *"10 Layers of Self-Improving Harness Stack"* (2026-06-16).
Alignment audit and per-layer gap analysis live in the vault at
`~/Documents/ai-lab-vault/80-Operations/10-layer-alignment-audit.md`.

This directory replaces the former empty `10-Stack/` scaffolding — the two naming
schemes are consolidated into the single name `10-layer-stack/`.

## The layers

| Layer | Name | Purpose | Status |
|-------|------|---------|--------|
| L1 | Stable Substrate | What stays fixed while the harness changes: base model, runtime, tools, task interface, evaluator, permissions | Implemented |
| L2 | Trace Log | The path, not just the answer: tool calls, file reads, retries, verifier output, costs, failures, state changes | Implemented |
| L3 | External State | Learning kept outside the model — skills, memory, natural-language policies, tool wrappers | Implemented |
| L4 | Failure Mining | Select the failures that teach a reusable lesson; do not feed every trace back | Implemented |
| L5 | Proposal Engine | Turn mined evidence into a candidate edit | Partial |
| L6 | Validation Gate | Reject edits that do not survive held-out evaluation. Without it the loop just overfits | Implemented |
| L7 | Versioning / Rollback | The harness should look like a repo, not a memory blob | Implemented |
| L8 | Routing & Variants | One harness cannot carry every lesson forever — route per task class | Implemented |
| L9 | Benefit Measurement | A harness update is not the same thing as a better agent; measure the delta | Designed (S190) — Phase 0 planned |
| L10 | Weight Update | Last resort, for behavior the harness cannot express | Designed (S190) — deferred, preconditions listed |

## Directory structure

```
10-layer-stack/
└── observability-stack/          # L2 trace log + L9 benefit measurement substrate
    ├── docker-compose.yml        # otel-collector, prometheus, grafana, node-exporter, langfuse
    ├── otel-collector.yml        # OTLP gRPC receiver -> prometheus + langfuse
    ├── prometheus.yml            # scrape config
    ├── grafana-dashboard.json    # four-agent architecture dashboard
    ├── grafana-provisioning/
    │   ├── datasources/prometheus.yml
    │   └── dashboards/provider.yml
    └── .env.example              # secret placeholders; copy to .env, never commit
```

New layer implementations get their own sibling directory here (for example
`proposal-engine/` for L5 or `benefit-measurement/` for L9).

## observability-stack

Serves L2 (trace capture) and the future L9 (benefit measurement) by collecting
AgentGateway traces and host/agent metrics.

Ports (all loopback-bound, registered in
`~/Documents/ai-lab-vault/80-Operations/port-registry.md`):

| Port | Service | Bind |
|------|---------|------|
| 31744 | OTel Collector OTLP gRPC | 127.0.0.1 |
| 31745 | AgentGateway `/metrics` | 127.0.0.1 |
| 31745 | Prometheus UI/API | 127.0.0.2 |
| 31746 | Grafana | 127.0.0.1 |
| 31747 | Langfuse | 127.0.0.1 |
| 31750 | node-exporter | 127.0.0.1 |

Prometheus binds the loopback alias `127.0.0.2` because both it and the
AgentGateway stats listener want port 31745.

### Startup (operator only)

The stack is **not** started automatically. Before first run, populate secrets:

```bash
cd ~/Github/nightforge/10-layer-stack/observability-stack
cp .env.example .env
# replace every REPLACE_* value with a generated secret
printf '%s' 'pk-lf-REPLACE:sk-lf-REPLACE' | base64 -w 0   # -> LANGFUSE_AUTH_STRING
```

Then start:

```bash
docker compose --env-file .env up -d
```

Restart / stop:

```bash
docker compose --env-file .env restart otel-collector prometheus grafana langfuse-web langfuse-worker
docker compose --env-file .env down
```

Do not run `docker compose down -v` — it destroys the persisted named volumes
(`prometheus_data`, `grafana_data`, `langfuse_postgres_data`,
`langfuse_clickhouse_data`, `langfuse_clickhouse_logs`, `langfuse_minio_data`,
`langfuse_redis_data`).

Full operator procedure, including AgentGateway wiring and rollback:
`~/Documents/ai-lab-vault/80-Operations/four-agent-architecture-operator-runbook.md`.
