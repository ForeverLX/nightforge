# Roadmap

This roadmap tracks the evolution of offsec-workstation from a reproducible host setup
to a production-grade Red Team operator environment.

## Phase 1 — Foundation ✅ COMPLETE
- Profile-driven installer
- Deterministic tmux layouts
- Directory contract (engage/loot/notes/exploitdev/projects)
- Minimal Neovim IDE (Telescope + rg/fd)
- Locked decision documentation

## Phase 2 — Workflow Hardening ✅ COMPLETE
- Refine manifests (base vs solo vs team)
- Remove accidental bloat
- Improve tmux ergonomics
- Harden loot handling (permissions + safe defaults)
- Audit enabled services for minimal surface

## Phase 3 — Performance + Package Audit (NEXT)
Goal: reduce package count (target: stay <900 if possible) without sacrificing operator workflow.

- Export full package inventory + classify (core / workflow / optional / remove)
- Remove overlaps (duplicate tools with the same job)
- Measure boot + session performance (track deltas)
- Record decisions in docs/performance + docs/DECISIONS

## Phase 4 — Container Profile Architecture ✅ COMPLETE
- ✅ Rootless Podman baseline (no daemon)
- ✅ Minimal "offsec-toolbox" base image (explicit mounts only)
- ✅ Three modular profiles: ad, re, web
- ✅ Wrapper scripts enforce directory contract mounts
- ✅ Version + date tagging for reproducibility
- ✅ Export/import for air-gapped engagements
- ✅ Package manifests: official repos only, documented exceptions

**Completed Feb 14, 2026**

### Built Profiles
- `toolbox:0.1.0` - Base layer (~1.1 GB)
- `ad:0.1.0` - Active Directory engagement tooling (~1.3 GB)
- `re:0.1.0` - Reverse engineering & vuln research (~1.8 GB)
- `web:0.1.0` - Web recon & enumeration (~1.1 GB)

### Known Limitations
- Some Python packages incompatible with Python 3.14 (using maintained alternatives)
- AUR tools like ffuf/naabu require manual install (using official alternatives)
- Per-engagement bring-up/tear-down (Mythic/Dradis) deferred to Phase 6

## Phase 5 — AI-VM Profile (Agentic, opt-in)
- OpenClaw introduced ONLY here (VM profile), sandboxed and opt-in
- Allowlist-only tools; no marketplace installs by default
- Strict mounts + explicit operator approval for host access

## Phase 6 — Engagement Orchestration
- Per-engagement C2 bring-up (Mythic, Sliver)
- Collaborative tooling (Dradis, CherryTree)
- Automated engagement teardown scripts
- Engagement versioning + snapshot management

## Phase 7 — archiso Build
- Convert profiles → archiso profile
- Minimal ISO build
- Solo + Team flavors
- Live boot + persistence options
