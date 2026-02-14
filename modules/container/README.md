# Container module (Podman rootless)

Canonical plan: `docs/CONTAINER.md`

This module will provide a portable operator container environment that mounts the workstation
directory contract:

- `~/engage`
- `~/loot`
- `~/notes`
- `~/exploitdev`
- `~/projects`

Principles:
- Rootless by default (no daemon)
- Explicit mounts only (no surprise host access)
- Minimal image surface (no “kitchen sink”)
- Per-engagement optional stacks live under `modules/container/compose/`

Non-goals:
- Replacing the host workstation
- Always-on host services (Mythic/Dradis are per-engagement)

Next steps (implementation):
1) Build `offsec-toolbox` image from `modules/container/toolbox/`
2) Add wrapper script to run toolbox with explicit mounts + sane defaults
3) Add bring-up / tear-down scripts for Mythic + Dradis under `modules/container/compose/`

