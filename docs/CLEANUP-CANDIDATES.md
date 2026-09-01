# Cleanup Candidates

Consolidated audit of stale/abandoned paths and deferred structure issues.
Nothing here has been deleted — each entry documents evidence, status, and
the recommended action. Update this file when a candidate is resolved.

## P1 — Stale Directory Audit (2026-08-01)

| # | Path | Evidence | Status | Recommended action |
|---|------|----------|--------|--------------------|
| 1 | `10-Stack/architecture/` | Empty directory, untracked, mtime 2026-07-20 | Abandoned scaffold | Remove (empty, untracked) or populate |
| 2 | `internal/cache/` | Empty directory, untracked, mtime 2026-07-26 | Abandoned scaffold | Remove or implement; harnessd uses no cache |
| 3 | `data/stream_store/` | Empty directory, untracked, mtime 2026-04-15 | Nightforged-era leftover | Remove — operator sign-off required (inside `data/`) |
| 4 | `data/state_store.db/` | Tracked dir containing binary `mem%3Ahealth.bin` (5.6KB, 2026-05-03) | Nightforged-era state store; no current reader (harnessd uses JSONL) | Removal = tracked-file deletion commit; operator sign-off required |
| 5 | `80-Operations/infra/langfuse/` | Empty directory, untracked, mtime 2026-07-20 | Abandoned scaffold | Remove or implement (Langfuse observability was planned) |
| 6 | `80-Operations/scripts/memory/` | Empty directory, untracked, mtime 2026-07-20 | Abandoned scaffold | Remove or implement |
| 7 | `modules/nightowl/` | `scripts/nightowl-layout.sh` (tmux layout), empty `docs/NIGHTOWL_INTEGRATION.md`, empty `manifests/`; `scripts/setup/directory-migration.sh` deletes `~/engage/nightowl`; `docs/DECISIONS.md` marks integration "locked" but stale | Legacy optional integration, appears inactive | Operator decision: keep as legacy or remove module |

## P2 — Batch 1 Remaining Candidates

| # | Issue | Evidence | Recommended action |
|---|-------|----------|--------------------|
| 8 | `internal/handler/routes.go` serves a legacy "Hermes BRAIN" role | Live table at `GET /api/v1/routes`; current guidance (AGENTS.md) deprecates Hermes, Pi is brain | Reconcile the static table (code change — separate pass, not docs) |
| 9 | `go.mod` module path `github.com/CR1MS0N-Operator/nightforge` vs remote `CR1MS0N-Operator/nightforge` | `go.mod` module line; `git remote -v` origin URL | Rename in a dedicated pass (breaks imports); update ARCHITECTURE.md after |
| 10 | Root `modules/Bar.qml` + `services/` vs `dotfiles/quickshell/` drift | Files differ; root is canonical per `main.qml` imports | Consolidate in a QML pass; keep one source |
| 11 | No `LICENSE` file | README claims MIT; no LICENSE in tree | Add a LICENSE file (operator decision on license text) |
| 12 | GitNexus index missing for nightforge | `gitnexus list_repos` registry contains only `euphrates` | Run `npx gitnexus analyze` + register repo; AGENTS.md section already documents this |

## Rules

- Do not delete anything in `data/` without explicit operator sign-off
- Empty untracked directories (1, 2, 3, 5, 6) can be removed safely, but
  removal should be deliberate — prefer `git clean` over hand deletion only
  after this doc is acknowledged
- Tracked removals (4) and code changes (8, 9, 10) belong to dedicated passes
