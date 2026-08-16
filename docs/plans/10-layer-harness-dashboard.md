# 10-Layer Harness Dashboard — Implementation Plan

> **For agentic workers:** Execute tasks sequentially. Each task produces independently testable output. Use TDD.

**Goal:** Replace nightforged Go system-monitor daemon with a 10-Layer Harness Dashboard — health monitoring, 10-layer status visualization, agent session tracking, and infrastructure oversight.

**Architecture:** Go backend on :9191 serving a static HTML/CSS/JS frontend. No DB. No npm build step. Health data collected every 5 min (built-in), layer/snapshot data read from vault files.

**Tech Stack:** Go 1.26+ (stdlib net/http, embed), vanilla HTML/CSS/JS (inline, no framework), matugen dark theme.

## Global Constraints

- Zero new runtime dependencies (Go stdlib only)
- No database — all data is file-based JSON
- Frontend: single HTML file, no build step, no npm
- Serve on `127.0.0.1:9191` (replaces existing nightforged)
- Matugen-themed dark palette (`#0D0F1A` bg, `#8B6FEF` primary, `#C8D0DC` accent)
- Existing `data/` directory structure preserved
- Cost tracking NOT in scope (flat $10/mo + free tiers — YAGNI)
- Token tracking: Option B — cron → hermes insights → JSON file → Go reads it

---

## Task 0: Fix local LLM + black box triage

### 0a: Create llama-server-bonsai.service

**Bonsai-27B Q1_0** on port :18234. Service unit is missing — model-switch.sh references it but file doesn't exist.

Create `~/.config/systemd/user/llama-server-bonsai.service`:
```ini
[Unit]
Description=llama-server — Bonsai-27B Q1_0 (fast tool-calling, 3.9GB)
After=network.target

[Service]
ExecStart=/home/ForeverLX/.local/bin/llama-server \
  --model /home/ForeverLX/models/Bonsai-27B-Q1_0.gguf \
  --host 127.0.0.1 --port 18234 \
  --alias Bonsai-27B \
  --ctx-size 65536 --n-gpu-layers 999 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --threads 8 --threads-batch 8 \
  --jinja
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

Then:
- `systemctl --user daemon-reload`
- `systemctl --user enable --now llama-server-bonsai.service`
- Verify: `curl http://127.0.0.1:18234/v1/models` returns model list
- Add `spawn-at-startup "systemctl" "--user" "start" "llama-server-bonsai.service"` to niri config.kdl
- Commit: `fix: add llama-server-bonsai.service systemd unit, enable on boot`

### 0b: Black box — identify spawner

Movable black window appears periodically. Need to identify the app-id.

When the black box appears, run:
```bash
niri msg focused-window
```
This returns the app-id and title of the window. Common suspects:
- `warpstash-ui` — clipboard history popup (dark theme, rounded corners)
- `qs-*` — Quickshell notification/widget popup
- `swaync` — notification popup rendering incorrectly

Once identified, the fix is either:
- **warpstash**: Check if something writes to clipboard periodically (cron, script, service)
- **Quickshell**: Check NotificationPopups.qml for rendering bug
- **swaync**: Check notification content causing black render

- [ ] On next appearance: `niri msg focused-window` → capture app-id
- [ ] Fix based on which app it is
- [ ] Commit: `fix: resolve periodic black window from [app]`

Dependencies: None.

---

## Task 1: Remove dead components

**Files to remove:**
- `cmd/nightforged/` — entire directory with main.go + internal/
- `session-tracker/` — entire Rust project
- `harness/` — entire Rust build directory
- `dashboard-ctl/` — entire Go CLI tool directory
- `.claude/`, `.aider*`, `.dmux/`, `.codegraph/`, `.gitnexus/` — stale agent artifacts

**But keep:**
- `dotfiles/` — active configs
- `scripts/` — active wallpaper/matugen scripts
- `docs/` — reference documentation
- `data/` — health history (1.9KB JSONL, keep for continuity)

- [ ] Verify each path exists before removing
- [ ] `rm -rf cmd/ session-tracker/ harness/ dashboard-ctl/`
- [ ] Remove stale config dirs
- [ ] Update `.gitignore`
- [ ] Commit: `chore: remove dead dashboard components (nightforged, session-tracker, harness, dashboard-ctl)`

Dependencies: None.

---

## Task 2: Go backend server

Replace the old `cmd/nightforged/` with new harness dashboard server.

**File structure:**
```
cmd/harnessd/main.go          — server entry point (:9191)
internal/handler/health.go    — GET /api/v1/health
internal/handler/layers.go    — GET /api/v1/layers
internal/handler/sessions.go  — GET /api/v1/sessions
internal/handler/snapshots.go — GET /api/v1/snapshots
internal/handler/routes.go    — GET /api/v1/routes
internal/collector/health.go  — system health collection (adapted from old code)
internal/server/server.go     — router, middleware, static file serving
```

**API endpoints** (reuse existing /api/v1 pattern):

```
GET  /api/v1/health        — system health snapshot (disk, mem, GPU, load)
GET  /api/v1/layers        — 10-layer implementation status (read from vault)
GET  /api/v1/sessions      — recent agent sessions (read from Hermes session dirs)
GET  /api/v1/snapshots     — L7 snapshot history (read from snapshot directory)
GET  /api/v1/routes        — L8 active model routes per agent
/*                         — serve embedded frontend
```

### Endpoint responses:

**GET /api/v1/health** — reads `data/history/health-YYYY-MM-DD.jsonl` (latest 24h):
```json
{
  "current": { "timestamp": "...", "health": { "disk_root_pct": 91, "mem_pct": 18, "gpu_mem": 5988, "load": [1.1, 1.4, 1.3] } },
  "history": [ ...latest 288 entries (24h at 5min intervals)... ]
}
```

**GET /api/v1/layers** — reads hardcoded layer list + checks vault for status flags:
```json
{
  "layers": [
    { "id": "L1", "name": "Hardware/Infra", "status": "complete", "description": "Arch Linux, Niri, NightForge" },
    { "id": "L2", "name": "Gateway/Cost", "status": "not-applicable", "description": "Flat-rate pricing, no tracking needed" },
    { "id": "L3", "name": "Routing", "status": "complete", "description": "v5 routing matrix in AGENTS.md" },
    { "id": "L4", "name": "Failure Mining", "status": "complete", "description": "549 entries classified" },
    { "id": "L5", "name": "Proposal Engine", "status": "complete" },
    { "id": "L6", "name": "Validation Gate", "status": "complete", "description": "5 gate rules" },
    { "id": "L7", "name": "Versioning & Rollback", "status": "complete" },
    { "id": "L8", "name": "Routing Matrix", "status": "complete" },
    { "id": "L9", "name": "Benefit Measurement", "status": "not-designed" },
    { "id": "L10", "name": "Weight Update", "status": "not-designed" }
  ]
}
```

**GET /api/v1/sessions** — reads `~/.hermes/sessions/` and `~/.omp/agent/sessions/` for recent session metadata:
```json
{
  "hermes": [
    { "id": "session_20260728_...", "started_at": "...", "status": "ended", "model": "deepseek-v4-flash" }
  ],
  "omp": [
    { "id": "019fabb7-...", "started_at": "...", "status": "ended", "model": "deepseek-v4-flash" }
  ]
}
```

**GET /api/v1/snapshots** — reads snapshot directory for L7 state:
```json
{
  "latest_snapshot": "2026-07-28T19:00:00Z",
  "total_snapshots": 12,
  "rollbacks": 0
}
```

**GET /api/v1/routes** — returns the v5 routing table from AGENTS.md / config:
```json
{
  "routes": [
    { "role": "Hermes BRAIN", "model": "deepseek-v4-flash", "provider": "opencode-go" },
    { "role": "OMP EXECUTOR", "model": "deepseek-v4-flash", "provider": "opencode-go" },
    { "role": "Subagents", "model": "deepseek-v4-flash-free", "provider": "opencode-zen" },
    { "role": "Pi/gnhf", "model": "ornith-1.0-9b-Q4_K_M", "provider": "local-llama" }
  ]
}
```

**Health collector** — adapt existing `internal/collector/` from old nightforged to write health JSONL in `data/history/health-{date}.jsonl` (already works, reuse the pattern).

- [ ] Create `cmd/harnessd/main.go` with HTTP server on :9191
- [ ] Create `internal/server/server.go` with router
- [ ] Create `internal/handler/health.go` — reads JSONL, returns current + history
- [ ] Create `internal/handler/layers.go` — returns hardcoded layer status
- [ ] Create `internal/handler/sessions.go` — reads Hermes + Pi session dirs
- [ ] Create `internal/handler/snapshots.go` — reads snapshot dir
- [ ] Create `internal/handler/routes.go` — returns routing table
- [ ] Create `internal/collector/health.go` — continues 5min health collection
- [ ] Test: `go build ./cmd/harnessd/`
- [ ] Test: start server, verify `curl http://127.0.0.1:9191/api/v1/health` returns 200
- [ ] Commit: `feat: add harnessd Go backend with health/layers/sessions/snapshots/routes endpoints`

Dependencies: Task 1 (clean slate).

---

## Task 3: Frontend

Single HTML page, matugen-themed, dark. No build step, no npm. Embedded in Go binary via `//go:embed`.

**File: `frontend/index.html`** — single file with inline CSS + JS.

**Layout:**
```
┌──────────────────────────────────────────────────────┐
│  ⚡ HARNESS DASHBOARD     [L4] [L5] [L6] [L7] [L8]  │  ← tab bar
├──────────────────────────────────────────────────────┤
│                                                       │
│  L4 Health tab (default):                             │
│  ┌──────────────────┐ ┌──────────────────┐           │
│  │ DISK             │ │ MEMORY           │           │
│  │ Root: 91% (4G)  │ │ 18% (7G/39G)     │           │
│  │ Home: 99% (7G)  │ │ GPU: 5.9G/8G     │           │
│  └──────────────────┘ └──────────────────┘           │
│  ┌──────────────────────────────────────────┐        │
│  │ LOAD: 1.1 1.4 1.3   │ 24h trend: ▁▃▂▁▄▃▂ │        │
│  └──────────────────────────────────────────┘        │
│                                                       │
│  L5 Proposals: Pending/applied proposals list        │
│  L6 Gates: Pass/fail counts per gate rule            │
│  L7 Snapshots: Timeline of snapshots + rollbacks     │
│  L8 Routes: Current model routing table              │
└──────────────────────────────────────────────────────┘
```

**Tabs:**
1. **L4 Health** — system health cards (disk, mem, GPU, load), 24h trend bar, failure counts
2. **L5 Proposals** — pending/applied proposals from vault (reads `/api/v1/layers`)
3. **L6 Gates** — validation pass/fail counts (reads `/api/v1/layers`)  
4. **L7 Snapshots** — last snapshot date, rollback history (reads `/api/v1/snapshots`)
5. **L8 Routes** — active model routes per agent (reads `/api/v1/routes`)

**Design tokens** (matugen dark):
- Background: `#0D0F1A`
- Primary: `#8B6FEF`
- Text: `#E6EAF0`
- Accent: `#C8D0DC`
- Card bg: `#1A1D2E`
- Border: `#2A2D3E`
- Font: system-ui sans-serif

**Tab switching** — JS `fetch()` on tab click, render response as cards. CSS-only bar charts (width %, no canvas).

- [ ] Create `frontend/index.html` — layout, tab bar, dark matugen theme
- [ ] Wire 5 tabs with JS fetch to API endpoints
- [ ] Auto-refresh health tab every 30s
- [ ] Create `internal/embed/embed.go` with `//go:embed frontend/index.html`
- [ ] Wire `/` route to serve embedded HTML
- [ ] Test: `go build ./cmd/harnessd/` with embedded frontend
- [ ] Test: open `http://127.0.0.1:9191/` in browser, verify all 5 tabs render data
- [ ] Commit: `feat: add harness dashboard frontend with 5-layer tabbed view`

Dependencies: Task 2 (API endpoints must exist).

---

## Task 4: Systemd unit

Replace the old `nightforged.service` with `harnessd.service`.

**Service file: `~/.config/systemd/user/harnessd.service`:**
```ini
[Unit]
Description=10-Layer Harness Dashboard
After=network.target

[Service]
Type=simple
ExecStart=%h/Github/nightforge/harnessd
Restart=on-failure
RestartSec=5
Environment=WAYLAND_DISPLAY=wayland-1

[Install]
WantedBy=default.target
```

**Note:** Health collection runs inside harnessd (5min ticker, same as old nightforged). No external cron needed for health.

- [ ] `systemctl --user stop nightforged.service`
- [ ] `systemctl --user disable nightforged.service`
- [ ] Write `harnessd.service` to `~/.config/systemd/user/harnessd.service`
- [ ] `systemctl --user daemon-reload`
- [ ] `systemctl --user enable --now harnessd.service`
- [ ] Verify: `curl http://127.0.0.1:9191/api/v1/health` returns data
- [ ] Verify: `systemctl --user is-active harnessd.service` → active
- [ ] Commit: `feat: add harnessd systemd unit`

Dependencies: Task 3 (harnessd binary with embedded frontend).

---

## Task 5: Verification

- [ ] `go build ./cmd/harnessd/` — clean build, no errors
- [ ] All CRUD dirs from Task 1 confirmed absent (`cmd/`, `session-tracker/`, `harness/`, `dashboard-ctl/`)
- [ ] `curl http://127.0.0.1:9191/api/v1/health` → 200 with JSON
- [ ] `curl http://127.0.0.1:9191/api/v1/layers` → 200 with 10 layers
- [ ] `curl http://127.0.0.1:9191/api/v1/sessions` → 200 with session list
- [ ] `curl http://127.0.0.1:9191/api/v1/snapshots` → 200 with snapshot data
- [ ] `curl http://127.0.0.1:9191/api/v1/routes` → 200 with routing table
- [ ] Frontend loads in browser, all 5 tabs render
- [ ] `systemctl --user is-active harnessd.service` → active
- [ ] `systemctl --user list-units --state=failed` → 0 loaded
- [ ] Commit: `chore: final verification — harness dashboard operational`

Dependencies: Tasks 1-4.

---

## Implementation Order

1. **Task 1** — Remove dead code (clean slate)
2. **Task 2** — Go backend (API must exist before frontend)
3. **Task 3** — Frontend (last because it needs API)
4. **Task 4** — Systemd (needs the binary from Task 2)
5. **Task 5** — Final verification
