# nightforge — Agent Rules

## Purpose

NightForge is the **AI-enhanced red team workflow platform** — the
**measurement and mobilization layer** of the CR1MS0N continuous adversarial
validation platform. The human is the **operator/orchestrator** of AI-enhanced
red team workflows; agents (below) are first-class participants in that
pipeline, not replacements for the operator.

This repository contains the hybrid-monorepo product (Rust-first CLI/theme/
wallpaper daemon + Go `harnessd`/`labd` control planes + QML shell), the
Omarchy 4.0 DE layer, rootless Podman container profiles, and the harness
pipeline that turns validation findings into proposals, gates, and measured
benefit.

## Agent Architecture (S210 stack — current)

> Two deployments of the same `harnessd` agent coordinator serve this repo:
> the **local lanes** executor (Pi Agent) and the **deepseek** executor (dsh).
> Each routes to a single local model via its own serving endpoint; see the
> live routing table (`GET http://127.0.0.1:9191/api/v1/routes`) for the
> authoritative model/provider mapping.

| Role | Agent | Scope |
|------|-------|-------|
| **brain / research** | **Hermes** | planning, proposals, decisions, roadmap |
| **deepseek executor** | **dsh** (`deepseek-harness`) | implements approved plans, code, docs, verification |
| **local lanes executor** | **Pi Agent** | local-lane execution; Qwen models via local endpoints |

### Model assignments (S210)

- **Hermes** (brain) — owned by the Hermes profile home; drives the roadmap.
- **dsh** (deepseek-harness) — routes to `cline-pass`/`deepseek-v4-flash` at
  `:3080` for execution-heavy work.
- **Pi Agent** (local lanes) — routes to local Qwen models:
  - quality lane: `Qwen3.8-27B` at `:18234`
  - aux lane: `Qwen3-1.7B` at `:18236` (CPU-only work)

Model/provider truth is the **live routing table** served by the harness at
`GET http://127.0.0.1:9191/api/v1/routes` (source:
`internal/handler/routes.go`). Do not hardcode model claims in docs; the
served table is authoritative.

Deprecated agents (OMP, Zero, pi-as-brain, Hermes-deprecated) are **removed**.
Do not reintroduce them; route new work to the three-agent S210 stack above.

## Session Strategy

- `--fork` — branch session for exploratory work
- `--continue` — resume prior session
- Use `docs/solutions/` and `docs/plans/` for cross-session context transfer

## GSD Workflow

Execute in order, adapted to this repo:

1. `go vet ./...`
2. `go build ./cmd/harnessd/`
3. `bash -n` on any changed `.sh` (CI-enforced; `shellcheck` optional locally)
4. CUE migration work: `go build ./cmd/cue-validate/` + validate against
   `cue/` schemas (see `docs/CUE-MIGRATION.md`)

## Harness Operations

```bash
go build ./cmd/harnessd/
./harnessd                       # 127.0.0.1:9191
curl -s http://127.0.0.1:9191/api/v1/health
systemctl --user status nightforge-harnessd   # deployed unit
```

Pipelines live in `scripts/harness/`; telemetry in `data/`; plans/solutions
in `docs/plans/` and `docs/solutions/`.

## Observability Stack

`10-layer-stack/observability-stack/` (Docker Compose: OTel, Prometheus,
Grafana, Langfuse, node-exporter) — L2/L9 substrate for AgentGateway traces
and host metrics. **Not started automatically.** Operator starts it after
populating `.env`; ports 31744–31750, all loopback-bound. See
`10-layer-stack/README.md`.

## Constraints

- **Never** modify or stage: `data/` (telemetry), `dotfiles/matugen/`
  (deploy state), `docs/plans/`, `harnessd.bak`
- **Never** push without explicit approval
- Stage only files you personally changed; prefer micro-commits with
  meaningful messages
- Do not modify application behavior or source logic in docs-only passes
- If a cleanup would risk deleting user work, stop and report it

## Documentation

- `README.md` — overview, quick start, harness API
- `ARCHITECTURE.md` — harness + desktop shell design
- `CONTRIBUTING.md` — contribution workflow
- `docs/INSTALL.md`, `docs/TROUBLESHOOTING.md` (top level), `docs/DECISIONS.md`

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is **not currently indexed** by GitNexus: `gitnexus list_repos`
shows only the `euphrates` repo in the registry. To re-enable code
intelligence here, run `npx gitnexus analyze` in this repo and register it.
Until then, prefer plain `grep`/`read` navigation.

If a GitNexus tool warns the index is stale, run `npx gitnexus analyze` first.
<!-- gitnexus:end -->

## Reference

- CR1MS0N context: `~/Documents/cr1ms0n-ops/CLAUDE.md`
