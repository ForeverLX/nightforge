# No-Mistakes Repo/Tool Research

> Generated: 2026-07-19 by FindNoMistakes scout
> Source: system inspection + vault cross-ref + NoMistakesSystemd peer

---

## Where is No-Mistakes Located?

| Item | Path | Details |
|------|------|---------|
| **Binary** | `~/.no-mistakes/bin/no-mistakes` | Statically linked ELF x86-64, 23.7MB |
| **Symlink** | `~/.local/bin/no-mistakes` | Points to binary above (on PATH) |
| **Global config** | `~/.no-mistakes/config.yaml` | YAML, agent wiring + pipeline settings |
| **State DB** | `~/.no-mistakes/state.sqlite` | SQLite, run/step/repo state |
| **Systemd unit** | `~/.config/systemd/user/no-mistakes-daemon-8d20ad62.service` | User-scoped, daemon launch |
| **SKILL doc** | `~/.agents/skills/no-mistakes/SKILL.md` | Agent skill for OMP/Hermes |
| **Old binary** | ~~`~/go/bin/no-mistakes`~~ | Deleted (v1.32.2 stale, shadowed new v1.37.0) |
| **Source repo** | `github.com/kunchenguid/no-mistakes` | Go binary, one `go install` |
| **Ecosystem** | **FirstMate toolchain** alongside GNHF, Treehouse, Lavish-AXI | All `kunchenguid/...` |

### Initialized Repos (9 registered)

| Dir Hash | Remote URL | Repo |
|----------|-----------|------|
| `ff6dd5de6292` | `git@github.com:CR1MS0N-Operator/ai-lab-vault.git` | ai-lab-vault |
| `f56459fbf053` | `<internal-gitea>/cr1ms0n-operator/veil.git` | veil |
| `ee55a8df2469` | `<internal-gitea>/cr1ms0n-operator/euphrates.git` | euphrates |
| `de26ea35d9e1` | `git@github.com:CR1MS0N-Operator/azrael-security.git` | azrael-security |
| `9edab0b7273b` | `git@github.com:CR1MS0N-Operator/security-research.git` | security-research |
| `5a6aaf5fd7cf` | `git@github.com:CR1MS0N-Operator/ACLGuard-Active-Directory-Permission-Auditor.git` | ACLGuard |
| `2d0cb17c1721` | `<internal-gitea>/cr1ms0n-operator/azrael-ops-dashboard.git` | azrael-ops-dashboard |
| `6ec5f2f9d76e` | `git@github.com:CR1MS0N-Operator/c4.git` | c4 (has actual branches pushed) |
| `1615b9d23356` | `git@github.com:CR1MS0N-Operator/nightforge.git` | nightforge |

Note: S115 handoff listed 8 "protected repos" (ACLGuard, azrael-ops-dashboard, c4, euphrates, nightforge, personal-site, security-research, veil). The current initialized set differs slightly: ai-lab-vault and azrael-security are registered; personal-site is absent. c4 repo at `6ec5f2f9d76e` has actual refs (`chore/l6-gate-v3`, `chore/l6-gate-doc-comment`) — it was used.

---

## What Does It Do?

**No-Mistakes is a local code-validation gate** — think "pre-PR CI/CD agent." When you push code through it, it runs a multi-step pipeline before the code reaches the configured push target:

```
git commit → push → [no-mistakes gate]
  ├── 1. Intent extraction — reads local agent transcripts, infers user goal
  ├── 2. Rebase — ensure branch is current
  ├── 3. Review — AI code review, flags issues (auto-fix vs ask-user)
  ├── 4. Test — run tests, auto-fix failures
  ├── 5. Document — generate/update docs
  ├── 6. Lint — lint, auto-fix
  ├── 7. Push + PR — push branch, open PR
  └── 8. CI Monitor — babysit PR until green (168h default timeout, auto-rebase)
```

**Key concepts:**
- **Gate-driven**: The pipeline stops at decision points (review findings, test failures) and waits for a human (or `--yes`) to respond with `approve`, `fix`, or `skip`.
- **Intent-aware**: The `--intent` flag captures the user's goal so the review step can distinguish deliberate choices from mistakes.
- **Auto-fix**: Test, lint, and document steps can auto-fix and re-run (configurable retries).
- **Session reuse**: Durable agent sessions across review loops (Claude/Codex).
- **TOON output**: Machine-readable `key: value` format for CLI parsing.

---

## What Language/Tools Does It Use?

| Layer | Technology |
|-------|-----------|
| Binary | **Go** — statically linked ELF x86-64 |
| Agent backend | **acp:omp** — `acpx` at `~/.npm-global/bin/acpx` |
| Model | **Ornith-1.0-35B** (Q4_K_M) via llama.cpp at `127.0.0.1:8081` |
| ACP command | `omp --model local-llama/Ornith-1.0-35B acp` |
| Config | YAML |
| State | SQLite |
| Output format | [TOON](https://toonformat.dev) |
| Daemon comms | Unix socket at `~/.no-mistakes/socket` |
| Worktree | Git worktree isolation (disposable per-push) |

The current agent is wired as:
```yaml
agent: acp:omp
acpx_path: /home/CR1MS0N-Operator/.npm-global/bin/acpx
acp_registry_overrides:
  omp: omp --model local-llama/Ornith-1.0-35B acp
```

---

## Why It Was Disabled

The systemd service `no-mistakes-daemon-8d20ad62.service` was **stopped in S141 and disabled in S147 Cleanup** for two reasons:

1. **0 repos initialized (at time of S140 install):** v1.37.0 was installed fresh in S140b via the official install script. The `~/.no-mistakes/repos/` directory was empty at that point because `no-mistakes init` had never been run in any of the 8 protected repos. The daemon ran with nothing to do.

2. **`agent: auto` resolved to nothing:** The original global config had `agent: auto`, which probes for native agents (claude, codex, rovodev, opencode, pi, copilot). Codex was removed in S091 (privacy incident). Claude/OpenCode/Pi/Copilot aren't installed. So `auto` found nothing runnable. The agent was later pinned to `acp:omp` (working local model), but the repos were never re-initialized under the new config.

**Status as of this research:**
- Daemon: **stopped** (no `daemon.pid` or stale socket)
- Systemd: **disabled** (`systemctl --user is-enabled` returns `disabled`)
- Agent wiring: **fixed** — config.yaml has `agent: acp:omp` with working acpx + OMP
- Repos: **9 registered** (apparently post-S140 someone initialized some or all) but none are active without the daemon
- c4 has actual branch refs (`chore/l6-gate-v3`, `chore/l6-gate-doc-comment`) — L6 gate was tested on c4 at some point

---

## How to Re-Enable

```bash
# 1. Verify agent wiring works
no-mistakes doctor

# 2. Re-init repos that need it (cd into each and run)
cd ~/Projects/veil && no-mistakes init
cd ~/Projects/euphrates && no-mistakes init
# ... repeat for all 8 target repos

# 3. Enable + start the daemon
systemctl --user enable no-mistakes-daemon-8d20ad62.service
systemctl --user start no-mistakes-daemon-8d20ad62.service

# 4. Verify it's healthy
systemctl --user status no-mistakes-daemon-8d20ad62.service
no-mistakes doctor
```

The agent is already pinned to `acp:omp` with working local model path. The key missing step is `no-mistakes init` in each target repo to register push hooks. After that, `git push no-mistakes <branch>` triggers the pipeline.

---

## How No-Mistakes Pairs with GNHF for an Overnight GNHF (Good Night Have Fun) Run

### The Tools

| Tool | Role | Binary | Agent |
|------|------|--------|-------|
| **GNHF** (v0.1.41) | Overnight agent orchestrator | `~/.npm-global/bin/gnhf` (Node.js) | `acp:omp` |
| **No-Mistakes** (v1.37.0) | Push-time validation gate | `~/.no-mistakes/bin/no-mistakes` (Go) | `acp:omp` |
| **Local LLM** | Shared reasoning engine | llama.cpp @ `127.0.0.1:8081` | Ornith-1.0-35B (24-29 tok/s) |

Both tools already share the same agent backend (`acp:omp` via acpx → OMP → local llama.cpp), so they use the same model without API costs.

### The Pairing Flow

```
                  OVERNIGHT AUTOMATION RUN
  ───────────────────────────────────────────────────────────

  BEFORE BED:
  1. Ensure clean git state in target repo
  2. GNHF config is already set: agent: acp:omp (confirmed)
  3. No-Mistakes daemon running + repos initialized

  ── GNHF phase (overnight) ──
  
  GNHF --agent acp:omp --max-iterations 50 --stop-when "..."
  │  Iterates until stop condition met or cap reached
  │  Each iteration: read task → implement → commit (success) / reset (fail)
  │  Writes commits to feature branch (gnhf/* or similar)
  │  Output: branch with incremental commits
  │
  └── After stop condition or iteration cap ──►

  ── No-Mistakes phase (morning validation) ──

  no-mistakes axi run --intent "overnight run: <goal>"
  │  Validates GNHF's output branch
  │  Steps: review → test → lint → push → PR
  │  Auto-fix where possible
  │  Output: report (passed/failed + findings)
  │
  └── User wakes up ──► reads report + branch diff

  AFTER MORNING COFFEE:
  1. Read no-mistakes report (what passed, what failed)
  2. Review GNHF commits on the branch
  3. Cherry-pick good commits, address failures
  4. Merge or iterate
```

### Why This Works

1. **Same agent backend** — Both use `acp:omp` with the same local model. No API key management, no config drift.
2. **Complementary strengths** — GNHF is good at *production* (iterate, code, commit). No-Mistakes is good at *quality* (review, test, lint, gate).
3. **Pipeline, not parallel** — The two tools don't fight: GNHF builds, No-Mistakes validates. Sequential by design.
4. **GNHF in worktree mode** — `--worktree` flag isolates the run to a clean worktree, doesn't touch the main checkout. Then No-Mistakes validates from that branch.
5. **Low cost** — Local Ornith 35B at 24-29 tok/s, zero API spend. Acceptable for unattended overnight runs where wall clock is not critical.
6. **Existing pairing doc** — `~/Documents/ai-lab-vault/10-Stack/gnhf-no-mistakes-pairing.md` already describes the flow.

### Prerequisites for Overnight Run

```bash
# 1. Start the daemon (required for no-mistakes pipeline)
systemctl --user start no-mistakes-daemon-8d20ad62.service

# 2. Init target repo if not done
cd <target-repo> && no-mistakes init

# 3. Verify both tools share the same agent
no-mistakes doctor   # should say acp:omp is runnable
gnhf --version       # should be >= 0.1.41

# 4. Ensure llama-server is running (local model)
systemctl --user status llama-server.service

# 5. Write comprehensive GNHF prompt covering all tasks
#    GNHF prompt skeleton in ~/.local/share/zero/skills/gnhf/SKILL.md
```

### Relevant Files

| Path | Description |
|------|-------------|
| `~/.no-mistakes/config.yaml` | No-Mistakes global config (agent: acp:omp) |
| `~/.gnhf/config.yml` | GNHF config (agent: acp:omp, conventional commits) |
| `~/.config/systemd/user/no-mistakes-daemon-8d20ad62.service` | Systemd unit |
| `~/Documents/ai-lab-vault/10-Stack/gnhf-no-mistakes-pairing.md` | Existing pairing strategy doc |
| `~/.agents/skills/no-mistakes/SKILL.md` | Agent skill for driving no-mistakes |
| `~/.local/share/zero/skills/gnhf/SKILL.md` | Agent skill for driving GNHF |
| `~/Documents/ai-lab-vault/80-Operations/Handoffs/s-series/azrael-handoff-S140-omp-successor-local-llm-truth.md` | S140 handoff with no-mistakes v1.37.0 install details |
| `~/Documents/ai-lab-vault/80-Operations/Handoffs/s-series/azrael-handoff-S141-routing-local-llm-harness-inventory.md` | S141 handoff — daemon stopped, unit still enabled |
| `~/Documents/ai-lab-vault/80-Operations/Handoffs/s-series/azrael-handoff-S142-t3mp3st-ornith-zero-herdr.md` | S142 handoff — agent pin needed |
