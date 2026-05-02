# nightforge — Agent Rules

## Purpose
Operator workstation for Azrael Security operations. Hosts T5 code tooling (OpenCode) and local development environment.

## Agent Personas
- **T5 code** (OpenCode + OpenCode Go) — development, infrastructure as code
- **plan** (DeepSeek V4.0 Flash) — reasoning, strategic planning
- **build** (Codestral) — execution, implementation

## Current Tooling
- OpenCode (:4097) — multi-model coding environment
- OpenCode Go subscription — paid tier access
- Obsidian — azrael-vault and ai-lab-vault
- Podman rootless quadlets — local container services
- Bifrost (:8080) — LLM gateway with routing

## Token Optimization Stack
- **Bifrost**: gateway + Code Mode (50-85% savings)
- **context-mode**: sandbox + compression (~98% savings)
- **RTK**: shell output compression (80-90% savings)
- **context-engineering-kit**: prompt templates

## Token Optimization
- `/dcp` — context pruning (uses @tarquinen/opencode-dcp)
- `/dcp compress` — smart compaction with summaries
- `/dcp sweep [n]` — prune last n tools
- `/compact` — manual compaction when auto triggers too late
- `/cost` — estimate session cost
- `/clear` — reset context for new task
- compaction.auto: true, prune: true, reserved: 16000

## Session Strategy
- `--fork` — branch session for exploratory work
- `--continue` — resume prior session
- Use handoff docs between sessions for context transfer

## GSD Workflow
- `.planning/` directory for task breakdowns
- STATE.md tracks progress
- Execute in order: lint -> typecheck -> test -> build

## Context Management
- Master context: ~/Documents/azrael-ops/azrael-master-context.md
- All infra changes documented in azrael-decisions.md
- Handoff documents track session state

## Model Selection
- Primary: opencode-go/kimi-k2.6 (reasoning)
- Fallback: openkilo (40 free models via Kilo AI)
- Free tier: openrouter/free (emergency)
- Plan: openrouter/deepseek/deepseek-v4.0-flash
- Build: openrouter/mistralai/codestral-2508

## Model Routing Pattern ($20/mo budget)
| Task Type | Model | Provider | Cost |
|-----------|-------|----------|------|
| Quick tasks | Big Pickle (GLM-4.6) | OpenCode Go FREE | $0 |
| Code generation | kimi-k2.6 | OpenCode Go | $0 (subscription) |
| Architecture | nvidia/nemotron-3-super | NVIDIA NIM | Free credits |
| Planning | deepseek-v4.0-flash | OpenRouter | ~$0.50/day |
| Premium fallback | OpenCode Zen | OpenCode Zen | Pay-as-you-go |

**Pattern:** Free tier first → subscription for heavy tasks → pay-as-you-go only if needed

### Provider Balances
| Provider | Balance | Model |
|---|---|---|
| OpenCode Go | $10/mo subscription | kimi-k2.6, GLM-5.1, Big Pickle |
| OpenCode Zen | ~$15-18 | Premium models |
| OpenRouter | ~$5 | deepseek-v4.0-flash |
| NVIDIA NIM | Free credits | nemotron-3-super, codestral |

**Pattern:** Default to cheap → escalate to mid → fallback to different cheap

## OPSEC Notes
- Internal services WireGuard-only (10.0.0.0/24)
- SSH keys: homelab-id_ed25519 for lab, id_ed25519 for GitHub only
- No credentials in chat history
- Never commit tokens, keys, or credentials
- No write outside project directory

## Plugins Installed
- @tarquinen/opencode-dcp — context pruning
- opencode-autoship — issue-to-PR orchestration
- opencode-direnv — env variable loading
- openkilo — 40 free fallback models
- opentmux — tmux integration
- cc-safety-net — safety checks

## Skills Available
- /caveman — compressed communication mode
- /azrael-project — project execution workflow
- strategic-compact — context compaction

## Reference
- See: ~/Documents/azrael-ops/AGENTS.md for full agent rules