# NightForge

**Operator workstation for CR1MS0N-Operator** — Arch Linux + Niri desktop
environment, rootless Podman container profiles, and the `harnessd`
monitoring dashboard. Part of the [Veil](https://github.com/CR1MS0N-Operator/veil)
infrastructure project.

Built and operated by [CR1MS0N-Operator](https://github.com/CR1MS0N-Operator).

## Status

| Aspect | Status |
|--------|--------|
| Version | Rolling (no versioned releases) |
| Active | Yes |
| CI | GitHub Actions (`.github/workflows/ci.yml`) |
| Tests | Go build + `go vet`, shellcheck, `bash -n` (CI) |
| Last Updated | 2026-08-01 |

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/CR1MS0N-Operator/nightforge.git
cd nightforge

# 2. Review what will be installed
less manifests/host-packages.txt
less docs/INSTALL.md

# 3. Deploy core dotfiles (GNU stow layout, per-directory)
./scripts/apply-dotfiles.sh

# 4. Install system packages (review first — dry run)
./install.sh --profile solo-operator --dry-run
# ./install.sh --profile solo-operator

# 5. Build container profiles (optional)
./modules/container/scripts/container.sh build-all

# 6. Build and run the harness dashboard
go build ./cmd/harnessd/
./harnessd    # serves http://127.0.0.1:9191

# 7. Validate the installation
./scripts/benchmark/system-baseline.sh
```

See [docs/INSTALL.md](docs/INSTALL.md) for the full procedure and
[profiles/](profiles/) for `local-only`, `solo-operator`, `team-operator`.

---

## Harness Dashboard (`harnessd`)

The active monitoring system: a Go backend on `127.0.0.1:9191` serving a
single-file HTML frontend. No database, no build step, no external
dependencies — stdlib only (`go.mod` has zero requires). Replaces the former
`nightforged` daemon.

- **Daemon:** `cmd/harnessd/main.go` — embeds the frontend, starts the health
  collector, serves all routes
- **Router:** `internal/server/server.go` — API + static frontend, CORS and
  request logging middleware
- **Handlers:** `internal/handler/` — one file per endpoint
- **Collector:** `internal/collector/health.go` — 5-minute health snapshot
  ticker, JSONL persistence
- **Frontend:** `cmd/harnessd/frontend/index.html` — inline CSS/JS, Matugen
  dark theme, 6 tabs, 30s auto-refresh on the health tab

### API

| Endpoint | Returns |
|----------|---------|
| `GET /api/v1/health` | Latest health snapshot + recent history + daily summary |
| `GET /api/v1/layers` | 10-layer harness status + proposals/gates/failures detail |
| `GET /api/v1/sessions` | Agent session list (Pi/OMP/Hermes session dirs) |
| `GET /api/v1/snapshots` | Snapshot inventory + rollback history |
| `GET /api/v1/routes` | Active model-routing table (from `internal/handler/routes.go`) |
| `GET /api/v1/cost` | Token usage + cost (`data/tokens/current.json`) |

### Data Store (`data/`)

| Path | Contents |
|------|----------|
| `data/history/` | Health snapshots, one JSONL per day |
| `data/snapshots/` | Versioned state snapshots (baselines) |
| `data/proposals/` | Proposal engine output (`proposals.json`) |
| `data/gates/` | Validation gate state (`gates.json`) |
| `data/failures/` | Failure-mining classification (`failures.json`) |
| `data/tokens/` | Token/cost tracking (`current.json`) |
| `data/cost/` | Per-session cost aggregates |

### Pipeline Scripts (`scripts/harness/`)

| Script | Role |
|--------|------|
| `pipeline-runner.sh` | Orchestrates the layer pipelines |
| `failure-miner.sh` | L4 — failure classification |
| `proposal-engine.sh` | L5 — proposal generation |
| `gate-check.sh` | L6 — validation gate rules (5 rules) |
| `snapshot-config.sh` / `rollback.sh` | L7 — versioning + rollback |
| `token-tracker.sh` | Token usage → `data/tokens/current.json` (30min cron) |
| `pi-session-parser.sh` | Cost data from OMP/Pi session JSONL |

### 10-Layer Harness

| Layer | Name | Status |
|-------|------|--------|
| L1 | Hardware/Infra (Arch, Niri, NightForge) | complete |
| L2 | Gateway/Cost (flat-rate, no tracking needed) | not-applicable |
| L3 | Routing (v5 routing matrix) | complete |
| L4 | Failure Mining | complete |
| L5 | Proposal Engine | complete |
| L6 | Validation Gate | complete |
| L7 | Versioning & Rollback | complete |
| L8 | Routing Matrix | complete |
| L9 | Benefit Measurement | not-designed |
| L10 | Weight Update | not-designed |

Run with `systemctl --user status harnessd` on the workstation. See
[ARCHITECTURE.md](ARCHITECTURE.md) for the full design and
[scripts/harness/](scripts/harness/) for the pipeline implementation.

---

## Desktop Stack

Wayland desktop built around Niri with a Quickshell overlay + top bar.
`dotfiles/niri/.config/niri/config.kdl` autostart (the "replace DMS" block):
`awww-daemon` (wallpaper), Quickshell overlay (`shell.qml`) + top bar
(`TopBar.qml`), `matugen-sync.sh` (theming), `podman-restart.service`,
`wallpaper-rotate.timer`, `mpd.service`.

| Component | Role |
|-----------|------|
| **Niri** | Scrolling-tiling Wayland compositor (per-monitor workspaces) |
| **Quickshell** | QML shell: overlay widgets (StackView) + per-screen bar |
| **Matugen** | Material You color extraction, template-based re-theming |
| **Ghostty** | GPU terminal, SIGUSR1 config reload for theme switching |
| **Zsh + Starship** | Prompt + operator terminal framework (<100ms startup) |
| **Podman** | Rootless container profiles (toolbox, ad, re, web) |

### Design Decisions (condensed)

- **Niri over Sway** — scrolling layout keeps window geometry stable during
  multi-window work; built-in overview; per-monitor workspaces.
- **Quickshell over eww/AGS** — GPU-accelerated QML, watcher-based scripts
  (no polling loops), live Matugen color sync.
- **Matugen** — HCT tonal palette extraction, one wallpaper → configs for
  Ghostty/GTK/Qt/Neovim/btop/Mako/Rofi/Starship/Quickshell.
- **Rootless Podman over Docker** — no daemon, `--userns=keep-id`, local
  images only, export/import for air-gapped work.
- **Ghostty over Kitty/Alacritty/WezTerm** — multi-config dark/light maps to
  OPSEC theme switching; SIGUSR1 reload.

Full rationale in [docs/DECISIONS.md](docs/DECISIONS.md).

### Container Profiles

Rootless Podman profiles, layered on a shared `toolbox` base:

| Profile | Purpose | Key Tooling |
|---------|---------|-------------|
| `toolbox` | Base runtime + Python | git, tmux, neovim, python, curl, jq, yq |
| `ad` | Active Directory engagement | Impacket, krb5, Samba, LDAP utils, RustHound-CE |
| `re` | Reverse engineering | radare2, GDB+gef, pwntools, ROPgadget, capstone, unicorn, Ghidra |
| `web` | Web recon | nmap, masscan, gobuster, httpx, nuclei, requests, go |

```bash
./modules/container/scripts/container.sh build-all   # build all profiles
./modules/container/scripts/container.sh build ad    # build one
./modules/container/scripts/container.sh run ad      # run (mounts engage/loot/notes/exploitdev/projects)
./modules/container/scripts/container.sh export ad   # air-gapped export .tar
```

> **Status:** Manifests and Containerfiles are version-controlled; treat
> profiles as in-progress and verify before use in engagements.

### Operator Terminal Framework

Contextual shell (dotfiles/operator-terminal): VPN/WireGuard status, active
engagement context, network awareness, podman status, git context, system
health, MITRE ATT&CK technique logging (`mitre log T1059.004 "…"`).

---

## Repository Structure

```
nightforge/
├── cmd/harnessd/            # Go daemon entry point (+ embedded frontend/)
├── internal/
│   ├── server/              # Router, middleware
│   ├── handler/             # API handlers (health, layers, sessions, snapshots, routes, cost)
│   ├── collector/           # 5-min health collector, JSONL persistence
│   └── cache/               # (empty — reserved)
├── data/                    # Harness telemetry (proposals, gates, failures, snapshots, tokens, cost, history)
├── scripts/
│   ├── harness/             # Pipeline scripts (failure-miner, proposal-engine, gate-check, …)
│   ├── maintenance/         # Weekly/monthly/quarterly upkeep
│   ├── audit/ benchmark/ engagement/ helpers/ recon/ security/ setup/
│   ├── qs-watcher/ niri-outputs/   # Small Go helpers
│   └── apply-dotfiles.sh, deploy.sh, matugen-sync.sh, …
├── dotfiles/                # Stow-style per-app configs (niri, quickshell, ghostty, matugen, …)
├── modules/                 # Quickshell QML sources (Bar.qml, widgets) + niri/ shell/ container/ nightowl/
├── services/                # Quickshell QML services (MatugenColors, MpdClient, VpnStatus, PodmanStatus)
├── manifests/               # Package lists (host, aur, container, ad/re/web tooling)
├── profiles/                # install.sh profiles (local-only, solo-operator, team-operator)
├── 10-Stack/ 80-Operations/ # Planning scaffolding (mostly empty — see report)
├── niri-modifications/      # Niri experiment scripts + README
├── system/optimizations/    # Sysctl/kernel tuning
├── docs/                    # INSTALL, ARCHITECTURE-referenced guides, plans/, solutions/, security/
├── .github/workflows/ci.yml # Go build/vet + shellcheck + bash syntax
├── AGENTS.md                # Agent guidance (pi/OMP/zero, harness ops)
├── CONTRIBUTING.md          # Contribution guide
└── TROUBLESHOOTING.md
```

---

## Performance & Benchmarks

Measured on the operator workstation (i3-10105F, GTX 1650):

| Metric | Value |
|--------|-------|
| Boot (systemd-analyze) | ~21.3s total (man-db 6.9s top offender) |
| Idle RAM | ~1.8 GB (Niri + Quickshell) |
| Terminal startup | ~87ms (operator framework) |
| Container build (toolbox) | ~3m45s first, ~30s cached |

Run `./scripts/benchmark/system-baseline.sh` for a full baseline
(`docs/benchmarks/` is gitignored — generated reports).

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — Niri start/config, container
build failures, terminal framework, Matugen theming, maintenance timers,
network/VPN.

---

## Changelog & Roadmap

- [CHANGELOG.md](CHANGELOG.md) — full history
- [docs/ROADMAP.md](docs/ROADMAP.md) — planned work

---

## Design Principles

1. **Reproducible by default.** Configs and manifests version-controlled; a
   fresh install should produce an identical environment.
2. **Minimal attack surface.** No Docker daemon, rootless containers, explicit
   mounts only.
3. **OPSEC-aware workflows.** Theme switching, VPN-aware terminal, engagement
   isolation, MITRE technique logging.
4. **Local-first.** All tooling runs locally; export/import for air-gapped ops.
5. **Maintainable over clever.** Boring tech (bash, KDL, QML, Go stdlib) with
   documented trade-offs.

---

## Disclaimer

All tooling is for authorized security research and engagement work only.
Sensitive configurations and live operational details are intentionally
excluded from this repository.

**Author:** Darrius Grate | CR1MS0N-Operator
**License:** MIT
