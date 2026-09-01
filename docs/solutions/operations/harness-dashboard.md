---
title: "10-Layer Harness Dashboard — replace nightforged with harnessd"
date: 2026-07-28
category: docs/solutions/operations
plan: docs/plans/10-layer-harness-dashboard.md
module: harnessd
problem_type: replacement
resolution_type: new_feature
severity: medium
tags: [harness, dashboard, migration, systemd]
---

# Harness Dashboard Implementation

## Plan Cross-Reference

Plan: Implementation plan attached to session (10-Layer Harness Dashboard)
Solution: `docs/solutions/operations/harness-dashboard.md`

## What Happened

### Task 0a: llama-server-bonsai.service

- Created `~/.config/systemd/user/llama-server-bonsai.service` with Bonsai-27B Q1_0 model
- Fixed `--n-gpu-layers 32` for 8GB RTX 3070 (999 caused OOM)
- Added spawn-at-startup to niri config.kdl
- Service enabled, model API responding on :18234

### Task 0b: Black box triage

- Blocked — requires window to appear. Diagnostic: `niri msg focused-window`

### Task 1: Remove dead components

- Deleted `cmd/nightforged/`, `session-tracker/`, `harness/`, `dashboard-ctl/`
- Removed `.claude/`, `.aider*`, `.dmux/`, `.codegraph/`, `.gitnexus/`
- Updated `.gitignore` to prevent reintroduction
- Kept `data/history/` for health data continuity
- Commit: `21358e9` "chore: remove dead dashboard components"

### Task 2: Go backend (harnessd)

- Module: `github.com/CR1MS0N-Operator/nightforge`
- Files created:
  - `cmd/harnessd/main.go` — entry point, embed frontend, start collector
  - `internal/server/server.go` — router with CORS, logging middleware
  - `internal/handler/health.go` — GET /api/v1/health
  - `internal/handler/layers.go` — GET /api/v1/layers (10 layers)
  - `internal/handler/sessions.go` — GET /api/v1/sessions
  - `internal/handler/snapshots.go` — GET /api/v1/snapshots
  - `internal/handler/routes.go` — GET /api/v1/routes (v5 routing matrix)
  - `internal/collector/health.go` — 5min health collection, JSONL persistence
- Zero new dependencies (Go stdlib only)
- Fixed: `var sessions []Session` → `make([]Session, 0)` to avoid null in JSON

### Task 3: Frontend

- Single `cmd/harnessd/frontend/index.html` with inline CSS + JS
- Matugen dark theme: `#0D0F1A`, `#8B6FEF` primary, `#E6EAF0` text
- 5 tabs: L4 Health (default), L5 Proposals, L6 Gates, L7 Snapshots, L8 Routes
- Auto-refresh health tab every 30s
- Embedded in Go binary via `//go:embed`

### Task 4: Systemd

- Created `~/.config/systemd/user/harnessd.service`
- Stopped/disabled old `nightforged.service`
- Enabled and started `harnessd.service`
- Service active, health collector running

### Task 5: Verification

All criteria pass:
- `go build ./cmd/harnessd/` — clean build
- Dead dirs confirmed removed (cmd/harnessd/ is new)
- All 5 API endpoints return 200
- Frontend renders in browser with live data
- `systemctl --user is-active harnessd.service` → active
- `systemctl --user list-units --state=failed` → 0

## Verification Evidence

```
=== API endpoints ===
/api/v1/health -> 200  (current + 21 history entries)
/api/v1/layers -> 200  (10 layers)
/api/v1/sessions -> 200 (hermes: 0, omp: 0)
/api/v1/snapshots -> 200 (latest: "", total: 0, rollbacks: 0)
/api/v1/routes -> 200  (4 routes)
=== Frontend ===
Heading: "HARNESS DASHBOARD"
Tabs: L4 Health, L5 Proposals, L6 Gates, L7 Snapshots, L8 Routes
Health data: 80% disk, 95% home, 26% mem, 1.3G GPU
Routes tab shows 4 active model routes
=== Systemd ===
harnessd.service: active
nightforged.service: stopped+disabled
No failed units: 0
```

## Deviations from Plan

- `embed.go` not created as separate file — embed is inline in `main.go`
- Session dirs may return empty until Hermes/OMP generate recent sessions
- Black box triage (Task 0b) deferred — requires visual observation

## Next Time

- Add systemd journal logging level control
- Consider moving frontend asset to `frontend/` directory at project root
- Black box: run `niri msg focused-window` when window appears
