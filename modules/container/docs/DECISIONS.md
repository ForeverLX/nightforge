# Container Profile Decisions (locked)

Goal: Exegol-style portability without a kitchen-sink image.

Principles:
- Explicit bind mounts only (no implicit home mounts)
- Per-engagement tooling (Mythic/Dradis are NOT host services)
- Host stays minimal; container provides “operator workspace”
- Reuse workstation directory contract:
  ~/engage, ~/loot, ~/notes, ~/exploitdev, ~/projects

Runtime:
- Default: podman rootless
- Compat: docker+compose only when required by a toolchain

Non-goals:
- Replacing Arch/archiso roadmap (containers complement, don’t replace)
- Cloud/AI features (deferred to AI-VM profile)

