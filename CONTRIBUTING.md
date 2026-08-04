# Contributing — NightForge

## Scope

NightForge is a single-operator workstation repository: desktop environment
(Niri / Quickshell / Matugen dotfiles), Podman container profiles, the
`harnessd` monitoring dashboard, the observability stack
(`10-layer-stack/observability-stack/`), and the CUE config migration
toolchain (`cue/` + `cmd/cue-*`). Keep changes conservative, evidence-based,
and scoped to what the task asks for.

## Prerequisites

- Go 1.26+ (`go.mod` declares `go 1.26.5`; the harness depends only on
  `go-chi/chi/v5` + stdlib)
- `bash`, `git`
- Optional: `podman` (container profiles), `quickshell`/`matugen`/`niri`
  (desktop shell work), `docker` + `docker compose` (observability stack),
  `cue` (config migration)

## Build & Run (harnessd)

```bash
go build ./cmd/harnessd/
go vet ./...
./harnessd                # serves http://127.0.0.1:9191
```

Verify:

```bash
curl -s http://127.0.0.1:9191/api/v1/health
```

The daemon runs as a systemd user service on the workstation
(`~/.config/systemd/user/harnessd.service`, deployed outside this repo).

## Shell / Script Work

- Run `shellcheck` on any changed `.sh` (CI enforces it)
- Run `bash -n` for syntax verification
- Keep scripts self-contained; prefer stdlib tooling over new dependencies

## Documentation Conventions

- **Plans** live in `docs/plans/<slug>.md` (approved implementation plans)
- **Solutions** live in `docs/solutions/<category>/<slug>.md` and
  cross-reference their plan
- Update `README.md` / `ARCHITECTURE.md` whenever structure changes; docs
  must match actual code and config
- The universal template at
  `/home/ForeverLX/Documents/ai-lab-vault/50-Exports/templates/repo-docs-template.md`
  is guidance only — keep docs project-specific and concise, no boilerplate

## Commits

- Conventional Commits (`feat`, `fix`, `docs`, `chore`, `ci`, …) — see `git log`
- Micro-commits: one logical change per commit, meaningful messages
- Stage **only your own files**. Never stage or modify these operator-owned
  paths: `data/` (telemetry), `dotfiles/matugen/` (deploy state),
  `docs/plans/`, `harnessd.bak`
- No push without explicit approval

## Constraints

- Do not modify application behavior or source logic during docs-only passes
- Do not touch generated telemetry or deployment data
- If a requested cleanup risks deleting user work, stop and report it
