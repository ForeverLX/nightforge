# nightforge — Agent Rules

## Purpose
Operator workstation for CR1MS0N-Operator operations. Hosts T5 code tooling (OpenCode) and local development environment.

## Session Strategy
- `--fork` — branch session for exploratory work
- `--continue` — resume prior session
- Use handoff docs between sessions for context transfer
- See [session-start](#session-start-protocol) and [session-handoff](#session-handoff-protocol) below

## GSD Workflow
- `.planning/` directory for task breakdowns
- STATE.md tracks progress
- Execute in order: lint -> typecheck -> test -> build

## Model & Provider Stack (S168 — v5 Routing)

| Role | Primary Model | Provider | Cost | Notes |
|------|--------------|----------|------|-------|
| **Hermes BRAIN** | deepseek-v4-flash | OpenCode Go ($10/mo) | ~$0.14/mo used | Planning, routing, research synthesis |
| **OMP EXECUTOR** | deepseek-v4-flash | OpenCode Go ($10/mo) | bundled | Coding, debugging, testing, CI/CD |
| **Subagents** | deepseek-v4-flash-free | OpenCode Zen Free | $0 | Free tier when Zen resets |
| **Pi/gnhf** | ornith-1.0-9b-Q4_K_M | Local llama.cpp | $0 | Offsec, local-only tasks |
| **Local Fallback** | ornith-1.0-9b-Q4_K_M | local-llama (:18234) | $0 | Fallback when cloud unavailable |

### Subagent Routing
| Subagent | Model | Provider | Notes |
|----------|-------|----------|-------|
| Coding | deepseek-v4-flash | OpenCode Go | OMP default |
| Research | deepseek-v4-flash | OpenCode Go | Fast + cheap |
| Review | deepseek-v4-flash | OpenCode Go | Quality gate |
| Offsec | ornith-1.0-9b | local-llama | Air-gapped |

### Provider Priority Chain (S168)
1. **OpenCode Go** ($10/mo flat) → deepseek-v4-flash for Hermes + OMP
2. **local-llama** → ornith-1.0-9b on :18234 (fallback, private, offline)
3. **OpenCode Zen Free** → DeepSeek V4 Flash Free, (subagents, daily cap)

**Budget:** $10/mo (Go) + $0 (Zen free) + $0 (local) = $10/mo
**Routing:** Go primary → local fallback → Zen subagents

## 10-Layer Self-Improving Harness (Backend Architecture)
```
L10  Weight Update          — ✅ Design: 10-Stack/Research/l9-l10-design.md
L9   Benefit Measurement    — ✅ Design: 10-Stack/Research/l9-l10-design.md
L8   Routing & Variants     ✅ Complete
L7   Versioning & Rollback  🟡 Partial (git-backed)
L6   Validation Gate        🟡 Design complete
L5   Proposal Engine        🔴 Design complete
L4   Failure Mining         🔴 Design complete
L3   External State         ✅ context-mode + skills + memory
L2   Trace Log              ✅ Hivemind + sessions
L1   Stable Substrate       ✅ Arch Linux, Hermes stack
```
Full doc: `10-Stack/10-layer-harness-build.md`

## Key Ports
| Port | Service | Purpose |
|------|---------|---------|
| 18234 | llama-server | Local LLM (Ornith-1.0-9B) |
| 3000 | Forgejo | Git service |
| 7545 | gitlawb | Git lawb peer |
| 8585 | memlawb | E2E encrypted agent memory |
| 4747 | context-mode | Insight dashboard |
| 9191 | nightforged | Operator dashboard |

Full registry: `80-Operations/port-registry.md`

## Hacker Overlays (Permanent Identity)

These overlays are ACTIVE ALWAYS — they define CR1MS0N operating style.

### Paranoia — Assume Compromise
- Never trust tool output at face value — cross-reference claims against primary sources (official docs, source code, raw API responses)
- Audit configurations before acting on them — if a config file has a suspicious value, verify it first
- Challenge assumptions — if something seems too easy, wrong, or unexpected, verify before proceeding
- Verify from source — check actual documentation or source code rather than relying on memory
- Trust but verify LLM output — the model can hallucinate commands, flags, file paths. Cross-check with `which`, `--help`, or docs before running anything destructive

### OPSEC — Operations Security
- Never expose credentials, tokens, or internal paths in shared output — use environment variable references, not literal values
- Confirm before destructive operations — always pause for user confirmation on irreversible actions
- `~/.xurl` and similar credential files must never be read, parsed, or sent to LLM context
- Auth commands with inline secrets are forbidden in agent sessions

### Lateral — Reframe Problems
- When stuck on one approach, find an adjacent one rather than brute-forcing
- Look for the unexpected path — the best solution is often not the first one
- Pivot when blocked rather than deepening the hole

## Session Protocols

### Session-Start Protocol
Run at session start:
1. **Check for recent handoffs:** `ls -t ~/Documents/ai-lab-vault/80-Operations/Handoffs/s-series/azrael-handoff-S*.md 2>/dev/null | head -1`
2. **Query memory for durable facts** — recall user prefs, env quirks, project decisions
3. **Confirm agent identity:** CR1MS0N (OMP agent, cr1ms0n profile)
4. **Load companion skills:** session-handoff, ponytail, caveman
5. **Check active profile:** cr1ms0n

### Session-Handoff Protocol
Write handoff when:
- Session interrupted mid-work
- Handing off complex state between sessions
- After completing a major phase with pending items

**Required sections:** Header (topic, session #, date, status), Session IDs, State summary, What Changed table, Key Decisions, Pending items (P0/P1/P2), Known Issues.

**Storage:** Full handoff → `~/Documents/ai-lab-vault/80-Operations/Handoffs/s-series/`
**Lightweight:** `retain` / `learn` for durable facts across sessions

## Additional Protocols

### Mid-Session Checkpoint
After every major task block (3+ tool calls):
1. Did I use the right skill for this, or did I hand-roll something?
2. Should I load a new skill for the next task?
3. Is ponytail relevant? (code review, audit, debt identification)
4. Should this approach be saved as a new managed skill?

### Skill Review Checkpoint
Before starting substantive work:
- Is there a skill that matches the current task type?
- Should ponytail commands fire? (review, audit, debt)
- Before writing new code: climb the ponytail ladder (YAGNI -> stdlib -> one line)

## Reference
- Global rules: ~/.config/opencode/AGENTS.md
- CR1MS0N context: ~/Documents/cr1ms0n-ops/CLAUDE.md
- Vault context: ~/Documents/ai-lab-vault/AGENTS.md

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **nightforge** (799 symbols, 802 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/nightforge/context` | Codebase overview, check index freshness |
| `gitnexus://repo/nightforge/clusters` | All functional areas |
| `gitnexus://repo/nightforge/processes` | All execution flows |
| `gitnexus://repo/nightforge/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
