# GNHF Repository Research

> Compiled: 2026-07-19
> Sources: GitHub (kunchenguid/gnhf), local file system audit, ecosystem catalog, handoff docs

## Where Is GNHF?

### Remote (GitHub)
- **Repo**: `kunchenguid/gnhf` — https://github.com/kunchenguid/gnhf
- **Stars**: ~3,299 · **Forks**: 237 · **License**: MIT
- **Language**: TypeScript (98.7%), ESM-only
- **Latest release**: v0.1.42 (2026-05-13)
- **Last push**: 2026-06-10

### Local Installation
- **npm global binary**: installed as `gnhf` v0.1.41 (per package audit). No longer in `~/.bun/bin/` but `~/.gnhf/config.yml` exists with defaults.
- **Config**: `~/.gnhf/config.yml` — agent set to `claude`, 3 max consecutive failures, sleep prevention on.
- **Zero skill**: `~/.local/share/zero/skills/gnhf/` — directory exists but `SKILL.md` is 0 bytes (empty/stale).
- **OpenCode skill** (was): part of the deleted `~/.config/opencode/` SDK (backed up to `90-Archive/` in S125 cleanup).
- **NOT locally cloned**: no clone in `~/Tools/cloned/`, `~/Projects/`, or `~/Documents/`.

## What Does It Do?

**"Before I go to bed, I tell my agents: good night, have fun"**

GNHF is an overnight autonomous coding-agent orchestrator. It runs a loop of:
1. Validate clean git state → create/use a `gnhf/` branch
2. Build an iteration prompt with shared context (`notes.md`)
3. Invoke the configured coding agent (non-interactive mode)
4. On success: commit changes, append to `notes.md`
5. On failure: `git reset --hard`, exponential backoff on retryable errors
6. Loop until: `--max-iterations`, `--max-tokens`, `--stop-when` condition met, or 3 consecutive failures
7. Print exit summary: branch, elapsed time, iterations, tokens, diff stats, log paths

### Key Features
| Feature | Description |
|---------|-------------|
| **Agent-agnostic** | Supports claude, codex, copilot, pi, rovodev, opencode, ACP targets |
| **Worktree mode** | `--worktree` launches each agent in isolated git worktree (parallel agents) |
| **Live branch mode** | `--current-branch --push` commits directly to current branch with auto-push |
| **Resume support** | Rerun on existing `gnhf/` branch to pick up where previous run left off |
| **Graceful interrupts** | 1st Ctrl-C = graceful stop (finish iteration), 2nd = force kill |
| **Exit summary** | Permanent stdout summary with branch, stats, review commands |
| **Failure handling** | Commit failure preserves work for repair; agent failures rollback; 3 consecutive = abort |
| **Runtime caps** | `--max-iterations`, `--max-tokens`, `--stop-when <natural language condition>` |

## Language & Tools

| Aspect | Detail |
|--------|--------|
| **Language** | TypeScript 5.8+, ESM-only |
| **Build** | `tsdown` (bundles to `dist/cli.mjs`) |
| **Package manager** | pnpm 11.1.1 |
| **CLI framework** | `commander` v14 |
| **Config format** | YAML (`js-yaml`) |
| **Tests** | vitest v4, coverage via @vitest/coverage-v8 |
| **ACP support** | `acpx` bundled for ACP-compatible agent targets |
| **Lint/Format** | ESLint + Prettier |
| **Runtime** | Node >=20 |

## Key Files & Entry Points

| Path | Role |
|------|------|
| `dist/cli.mjs` | Published binary — declared in `package.json` `bin` field |
| `src/cli.ts` | CLI entry point, Commander setup, arg parsing, stdin piping |
| `src/core/orchestrator.ts` | Main orchestrator loop: iterate → invoke agent → commit/rollback |
| `src/core/config.ts` | Config loading/validation from `~/.gnhf/config.yml` |
| `src/core/git.ts` | Git operations: branch, commit, reset, push, worktree |
| `src/core/run.ts` | Run setup, resume, metadata persistence |
| `src/core/agents/factory.ts` | Agent factory: routes `--agent` flag to correct implementation |
| `src/core/agents/types.ts` | Agent interface, output types, token usage |
| `src/core/agents/claude.ts` | Claude Code agent implementation |
| `src/core/agents/codex.ts` | OpenAI Codex agent implementation |
| `src/core/agents/copilot.ts` | GitHub Copilot CLI agent implementation |
| `src/core/agents/opencode.ts` | OpenCode agent (starts local server) |
| `src/core/agents/pi.ts` | Pi CLI agent implementation |
| `src/core/agents/acp.ts` | ACP target agent (via acpx) |
| `src/core/agents/rovodev.ts` | Rovo Dev agent (starts acli serve) |
| `src/core/commit-message.ts` | Commit message generation (default or conventional commits) |
| `src/core/sleep.ts` | Sleep prevention (caffeinate / systemd-inhibit / PowerShell) |
| `src/core/debug-log.ts` | Debug logging to `.gnhf/runs/<runId>/gnhf.log` |
| `src/renderer.ts` | TUI renderer with live status, meteors |
| `~/.gnhf/config.yml` | User config (agent selection, path overrides, limits) |
| `.gnhf/runs/<runId>/` | Per-run metadata: prompt.md, notes.md, iteration-*.jsonl |

## Architecture

```
gnhf "<prompt>"
    │
    ▼
┌─────────────────────────────────────┐
│  src/cli.ts                         │
│  - Parse args + stdin               │
│  - Load config (~/.gnhf/config.yml) │
│  - Validate clean git               │
│  - Create/resume gnhf/ branch       │
│  - Init debug log + telemetry       │
└──────────┬──────────────────────────┘
           ▼
┌─────────────────────────────────────┐
│  src/core/orchestrator.ts           │
│  Loop until cap or failure:         │
│   1. Build iteration prompt         │
│   2. Invoke agent (factory.ts)      │
│   3. Parse JSON output              │
│   4. Commit or rollback             │
│   5. Append notes.md                │
│   6. Check stop conditions          │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Agent implementations               │
│  claude.ts / codex.ts / copilot.ts   │
│  opencode.ts / pi.ts / rovodev.ts    │
│  acp.ts (via acpx for any ACP agent) │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────┐
│  Exit summary (exit-summary.ts)     │
│  - Branch, elapsed time             │
│  - Iterations, tokens, diff stats   │
│  - Notes/log paths, review commands │
└─────────────────────────────────────┘
```

## How GNHF Pairs With No-Mistakes

### Direct Integration (gnhf already uses no-mistakes)

1. **Mandatory gate for contributions**: gnhf's `CONTRIBUTING.md` requires all human PRs to `main` pass through no-mistakes. A GitHub Actions check (`Require no-mistakes`) enforces this — PRs without the no-mistakes signature are not merged.

2. **Repo config**: gnhf ships its own `.no-mistakes.yaml` (turns off evidence storage in repo).

3. **Own CI workflow**: `.github/workflows/no-mistakes-required.yml` validates the no-mistakes signature on PRs.

### Overnight Automation Stack

GNHF and no-mistakes are complementary layers in the FirstMate ecosystem:

```
           Overnight Run
               │
   ┌───────────▼──────────────┐
   │   gnhf (orchestrator)    │  ← generates commits iteratively
   │   --agent claude         │
   │   --max-iterations 20    │
   └───────────┬──────────────┘
               │ commits to gnhf/<slug> branch
               ▼
   ┌───────────────────────────┐
   │  Morning Review           │  ← human reviews gnhf output
   │  (SKILL.md: Companion)    │
   └───────────┬──────────────┘
               │ git push no-mistakes
               ▼
   ┌───────────────────────────┐
   │  no-mistakes (quality)    │  ← AI review → test → lint → PR
   │  disposable worktree      │
   │  auto-fix or escalate     │
   └───────────┬──────────────┘
               │ clean PR
               ▼
          main branch
```

### Workflow Scenarios

| Scenario | gnhf role | no-mistakes role |
|----------|-----------|-----------------|
| **Nightly build + test** | Runs iterations all night | Gates resulting PR in morning |
| **Parallel feature work** | `--worktree` spawns N agents | Each agent's output gated separately |
| **Iterative refactoring** | Commits incremental improvements | Validates safety before merge |
| **Bug fix marathon** | Multiple fix attempts, rollback on fail | Ensures fix passes lint/test/review |
| **CI/tooling tasks** | Runs until condition met | Provides final quality assurance |

### Shared Ecosystem Integration Points

1. **Treehouse** (also by kunchenguid): worktree pool management — gnhf uses `--worktree` for isolation, no-mistakes uses disposable worktrees for pipeline isolation. Both could use treehouse for pooled worktree management.

2. **AXI** (also by kunchenguid): agent-optimized CLI design — both tools use AXI conventions (TOON format, agent-facing interfaces).

3. **SKILL.md pattern**: Both ship agent-facing skill files (`skills/gnhf/SKILL.md`, no-mistakes installs `/no-mistakes` skill) for agent self-orchestration.

### Current Status on This System

| Component | Status |
|-----------|--------|
| `gnhf` CLI | Installed (npm global, v0.1.41) |
| `~/.gnhf/config.yml` | Present (default config, agent: claude) |
| gnhf Zero skill | Directory exists, SKILL.md empty (0 bytes) |
| gnhf OpenCode skill | Deleted with OpenCode SDK (backed up) |
| no-mistakes CLI | Installed (Go binary, per ecosystem catalog) |
| no-mistakes `git push` remote | Possibly configured in some repos |

### Action Items for Overnight Run

1. **Re-install/refresh gnhf**: `npm install -g gnhf@latest` (upgrade from v0.1.41 to v0.1.42)
2. **Populate Zero skill**: Copy SKILL.md from GitHub or restore from backup archive
3. **Set up gnhf config**: Verify `~/.gnhf/config.yml` agent selection (currently `claude`)
4. **Initialize no-mistakes gate**: `no-mistakes init` in target repos that need gating
5. **Configure target repos**: Ensure they have worktree-compatible setup for `--worktree` mode
6. **Verify no-mistakes pipeline agent**: no-mistakes needs a configured pipeline agent (claude/codex/etc.)

## References

- gnhf repo: https://github.com/kunchenguid/gnhf
- no-mistakes repo: https://github.com/kunchenguid/no-mistakes
- no-mistakes docs: https://kunchenguid.github.io/no-mistakes/
- Hermes ecosystem catalog: `80-Operations/hermes-reference/hermes-ecosystem-catalog.md`
- Handoff S136: `80-Operations/Handoffs/s-series/azrael-handoff-S136-llmtrim-tool-discovery.md`
- Package audit: `20-Tools/Audits/package-audit-2026-07-12.md`
