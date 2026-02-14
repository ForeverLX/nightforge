# Decisions

This file records project decisions to keep the workstation reproducible and avoid drift.

## Scope / Direction

- Base platform: Arch Linux (rolling) with a future path to archiso for a distro build.
- Focus: Red Team operator workflows (not a generic pentest distro).
- Reproducible by default: pacman packages + versionable config files.
- Local-first baseline. Cloud/AI is opt-in later (likely as a VM-focused profile).

## Profiles (locked)

1) local-only.profile
- Minimal baseline
- Local-first

2) solo-operator.profile
- Daily-driver profile
- Terminal: Ghostty
- Local-first

3) team-operator.profile
- Standardized, production-grade defaults
- Terminal: Kitty
- tmux included by default

We explicitly do NOT include WezTerm.

## Directory contract (locked)

Standard roots:
- ~/engage
- ~/loot
- ~/notes
- ~/exploitdev
- ~/projects

Engagement layout (per name):
- ~/engage/<name>
- ~/loot/<name>
- ~/notes/<name>
- ~/exploitdev/<name>

## tmux layouts (locked)

- Base operator layout:
  - scripts/tmux-layout.sh

- Per-engagement layout:
  - scripts/tmux-engage.sh <name>

- NightOwl layout (optional, docs-only integration):
  - modules/nightowl/scripts/nightowl-layout.sh

## NightOwl integration approach (locked)

- NightOwl is a separate repo and remains independent.
- offsec-workstation provides:
  - deterministic session layouts
  - directory contract
  - docs for paths and evidence handling
- NightOwl code path:
  - ~/projects/nightowl
- NightOwl run artifacts:
  - ~/engage/nightowl/runs

## Container artifact (later)

- A team-ready container environment is planned later, after:
  - profiles/manifests stabilize
  - NightOwl paths stabilize
- Likely modeled after an Exegol-style approach (containerized operator environment + wrapper).
