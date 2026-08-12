# Roadmap

NightForge evolves in two tracks: the **workstation** (reproducible host,
desktop shell, toolchains) and the **validation platform** (10-layer harness,
observability, measurement). Completed items are recorded in
[CHANGELOG.md](../CHANGELOG.md); this document tracks what is next.

## Workstation Track

### Phase 1 — Foundation ✅ COMPLETE
- Profile-driven installer
- Deterministic tmux layouts
- Directory contract (engage/loot/notes/exploitdev/projects)
- Minimal Neovim IDE (Telescope + rg/fd)
- Locked decision documentation

### Phase 2 — Workflow Hardening ✅ COMPLETE
- Refine manifests (base vs solo vs team)
- Remove accidental bloat
- Improve tmux ergonomics
- Harden loot handling (permissions + safe defaults)
- Audit enabled services for minimal surface

### Phase 3 — Container Profile Architecture ✅ COMPLETE (2026-02)
- Rootless Podman baseline (no daemon)
- Minimal `toolbox` base image (explicit mounts only)
- Three modular profiles: `ad`, `re`, `web`
- Wrapper scripts enforce directory-contract mounts
- Version + date tagging; export/import for air-gapped engagements

### Phase 4 — Desktop Shell Modernization ✅ COMPLETE
- Niri compositor migration (from Sway)
- Quickshell shell + per-screen bar (from waybar)
- Matugen Material-You theming across all apps
- Ghostty terminal with OPSEC theme switching

### Phase 5 — Config Management (NEXT)
- Finish CUE migration of Niri config (`cue/` + `cmd/cue-*`)
- Extend CUE schemas to more config surfaces (Quickshell, Ghostty)
- Keep `fidelity-check` green on the live workstation

### Phase 6 — archiso Build (planned)
- Convert profiles → archiso profile
- Minimal ISO build, solo + team flavors
- Live boot + persistence options

## Validation Platform Track

### Phase A — 10-Layer Harness ✅ COMPLETE
- `harnessd` dashboard (Go, `127.0.0.1:9191`) replaces `nightforged`
- Pipeline scripts: failure mining (L4) → proposals (L5) → gates (L6) →
  versioning/rollback (L7) → routing (L8)
- JSONL evidence store under `data/`

### Phase B — Observability Substrate ✅ COMPLETE
- OTel Collector, Prometheus, Grafana, node-exporter, Langfuse
  (`10-layer-stack/observability-stack/`)
- AgentGateway trace + host/agent metric collection (loopback-only ports)

### Phase C — Benefit Measurement (NEXT)
- **L9** — FAIR-modeled benefit measurement from validation evidence
  (risk reduction quantified in dollars)
- **L10** — weight update loop from measured benefit back into routing
- Depends on the observability substrate (Phase B) and a stable routing table

## Historical Notes

- The workstation was originally branded `offsec-workstation` (pre-2026);
  docs, branding, and config paths now use **NightForge** — report any
  stragglers as issues.
- Performance work is tracked in [docs/performance-optimization.md](performance-optimization.md).
