# 10-Layer Self-Improving Harness — Full Build

**Date:** 2026-06-20 (S083/084 design), 2026-07-18 (S140 reality sync), 2026-07-19 (S148 architecture review)
**Author:** Azrael-Orchestrator
**Session:** S083/084 design, S140 routing reality sync, S148 2026 best-practice alignment
**Status:** L4 ✅ Implemented (failure-miner.sh, daily cron) | L5 ✅ Implemented (proposal engine, ranking matrix) | L6 ✅ Implemented (5 gate rules) | L7 ✅ Implemented (snapshot + rollback) | **Memory Layer 🟡 Implemented (hivemind-init.sh, session-end-hook.sh, consolidation-cron.sh, decay-scoring.sh)** | **Observability 🟡 Langfuse stack ready, OMP instrumentation pending** | L8 ✅ Complete | L9/L10 🔴 Not designed
**Previous Reference:** `azrael-agent-architecture-final.md`, `skills-mcp-audit-comprehensive.md`, `azrael-handoff-S082-stack-transition-purge-audit.md`

---

## S140 Reality Sync (2026-07-18)

**The L8 routing tables below were designed S083/084 against a different stack (Hermes profiles + OCG Go + OpenRouter). Reality has shifted:**

1. **Pi Agent (Zero) is dead** (S139). OMP became the sole dispatch agent. OMP IS the Pi Agent successor — same `omp` binary, same `pi-coding-agent` config lineage (`~/.omp/`), same `--smol/--slow/--plan` role pattern, same skill/hook/plugin/extensions architecture. S139 documented the routing change.
2. **Hermes default model is now `minimax-m3` (not `glm-5.2`)** — GLM 5.2 was failing every call, M3 is the available/reliable choice. S137/S139.
3. **OMP is the live harness with 5 model roles** wired to opencode-go (22 models), openrouter (7), opengateway (2), and local-llama (127.0.0.1:8081, ornith-1.0-35b-Q4_K_M). Approval mode yolo.
4. **Local LLM is 35B Ornith via llama.cpp, not Qwen3-4B via Ollama** — the S046 decision entry is stale. Qwen3-4B was a placeholder; 35B Ornith is the real deployment (20GB Q4_K_M, 66K context, runs in 4GB VRAM via CPU offload).
5. **L4-S (Static Code Mining) is now feasible** — `knip`, `madge`, `jscpd` all run via `npx` from OMP. No new dependencies.
6. **OMP v17.0.4 is itself a multi-role harness** that subsumes what Zero was supposed to be — fast daily driver + smol model + plan model + slow model + skill loading. No "replacement" needed.

**Action: Read S140 Addendum (end of doc) for current routing tables that supersede L8.1 / L8.2 / L8.4 / Appendix A. L8.3 decision tree is still conceptually valid — model names stale, but routing logic is correct.**


---

## S148 Architecture Review — 2026 Best-Practice Alignment (2026-07-19)

**Context:** Researched 2026 AI agent architecture patterns (Internative, Arahi AI, Knowlee, O'Reilly, NKKTech) and aligned our 10-layer design against the industry-standard 7-layer stack. Full analysis at `10-Stack/10-layer-architecture-review-2026.md`.

### Current Implementation State (S148)

| Layer | S138 Status | S148 Status | What Changed |
|-------|------------|-------------|--------------|
| L4 Failure Mining | 🔴 Design | 🟢 **Implemented** | `failure-miner.sh` + systemd timer (549 entries classified) |
| L5 Proposal Engine | 🔴 Design | 🟢 **Implemented** | `proposal-engine.sh` + ranking matrix + auto-apply rules |
| L6 Validation Gate | 🟡 Design | 🟢 **Implemented** | 5 gate rules: config-syntax, MCP-endpoint, model-responds, destructive, credentials |
| L7 Versioning & Rollback | 🟡 Partial | 🟢 **Implemented** | `snapshot-config.sh`, `rollback.sh`, `rollback-on-failure.sh` |
| L9 Benefit Measurement | 🔴 Not designed | 🔴 Not designed | Deferred — needs eval framework first |
| L10 Weight Update | 🔴 Not designed | 🔴 Not designed | Deferred — needs L9 operational first |

### 6 Critical Gaps Identified vs 2026 Standard

| Gap | Severity | Current Coverage | Fix |
|-----|----------|-----------------|-----|
| **No Gateway layer** — unified cost tracking, retry, request logging | P0 | ❌ Nothing installed (no LiteLLM/Portkey/Helicone) | OpenRouter Analytics API + Usage Accounting (free, built-in) |
| **No Observability/Tracing** — L4 only catches errors, not traces | P1 | ❌ No Langfuse/Helicone/OpenTelemetry | Deploy Langfuse self-hosted (MIT) — solves tracing + cost |
| **L4 taxonomy too shallow** — 7 categories vs 21 in AgentEval | P1 | ⚠️ 7 categories implemented | Expand to AgentEval taxonomy (add planning loops, memory errors) |
| **No formal Memory layer** — context-mode + Hivemind exist but unarchitected | P2 | ⚠️ Context-mode (short-term) + Hivemind (event DB) exist | Document 3-tier architecture, add pgvector for long-term |
| **No eval-driven optimization** — proposals are static, no A/B testing | P2 | ❌ Manual proposal review only | Integrate AgentEval DAG evaluation framework |
| **L9/L10 too vague** — benefit measurement and weight update undefined | P2 | ❌ Not designed | Redesign around eval-driven quality metrics + Langfuse data |

### Proposed 10-Layer v2.0 Redesign

```
Current Layer           → v2.0 Layer              Rationale
──────────────────────────────────────────────────────────────────
L1: Hardware/Infra       L1: Hardware/Infra       (unchanged)
L2: LLM Providers        L2: Gateway              (add: unified proxy, cost tracking, retry)
L3: Routing              L3: Routing              (add: cost-aware, A/B test, dynamic fallback)
L4: Failure Mining       L4: Observability        (add: Langfuse traces, AgentTelemetry spans)
L5: Proposal Engine      L5: Evaluation           (add: AgentEval DAG eval, quality metrics)
L6: Validation Gate      L6: Guardrails           (add: policy engine, sandbox, audit trail)
L7: Versioning/Rollback  L7: Versioning/Rollback  (add: trace rollback, eval-gated deploys)
L8: Routing Matrix       —→ absorbed into L3      (matrix is L3 data, not a separate layer)
L9: Benefit Measurement  L8: Optimization         (eval-driven tuning, A/B results)
L10: Weight Update       L9: Auto-adaptation      (closed-loop weight adjustment via eval data)
                         L10: Memory              (new: formal 3-tier memory architecture)
```

**Key changes in v2.0:**
- Merge L3 + L8 (routing matrix is data for L3, not a separate layer)
- Upgrade L4 from error-scraping to full observability with tracing
- Upgrade L5 from manual proposals to automated evaluation
- Add L10 Memory as a formal layer (short-term/working/long-term)
- L9/L10 become Optimization + Auto-adaptation (eval-driven loop)

### Recommended Implementation Order (Post-S148)

1. **P0 — OpenRouter Analytics** (30 min): Script to query OR Analytics API → `40-Memory/cost-logs/`
2. **P1 — Langfuse deploy** (2h): Docker compose, PostgreSQL + ClickHouse, instrument OMP
3. **P1 — L4 taxonomy expansion** (1h): Add planning/reasoning/memory error categories
4. **P2 — Memory layer design** (1h): Document 3-tier architecture, no new code
5. **P2 — Eval integration** (3h): AgentEval DAG evaluation pipeline
6. **P2 — L9/L10 redesign** (2h): Define quality metrics, tuning formulas
---

## Architecture Overview

The 10-layer harness is a self-improving agent orchestration stack. Each layer above L3 provides feedback, validation, or intelligence that makes the agents below it more reliable over time.

```
┌──────────────────────────────────────────────────────────────┐
│                   10-LAYER SELF-IMPROVING HARNESS             │
│                                                               │
│  L10  Weight Update          ── not yet designed              │
│  L9   Benefit Measurement    ── not yet designed              │
│  L8   Routing & Variants     ── ✅ THIS DOCUMENT              │
│  L7   Versioning & Rollback  ── 🟡 partial (git-backed)      │
│  L6   Validation Gate        ── 🟡 THIS DOCUMENT              │
│  L5   Proposal Engine        ── 🔴 THIS DOCUMENT              │
│  L4   Failure Mining         ── 🔴 THIS DOCUMENT              │
│  L3   External State         ── ✅ context-mode + skills      │
│  L2   Trace Log              ── ✅ Hivemind + sessions        │
│  L1   Stable Substrate       ── ✅ Arch Linux, Hermes v0.17   │
└──────────────────────────────────────────────────────────────┘
```

---

## L8 — Routing & Variants

**Status:** ✅ Complete — definitive decision tree for task-to-tool routing.

### L8.1 Hermes Profile Routing

Every Hermes profile is a "variant" — a distinct model + provider + MCP combo optimized for a task class.

Profile | Model | Provider | Base URL | Cost | Context | Best For |
|--------|-------|----------|----------|------|---------|----------|
| **cr1ms0n** (main) | big-pickle | OCG Zen | `opencode.ai/zen/v1` | $0 (sub) | varies | Daily driver — planning, coding, orchestration, writing |
| **offsec** | deepseek-v4-flash:free | OpenRouter | `openrouter.ai/api/v1` | $0 | varies | Red team, prompt injection, jailbreak research |

### L8.2 OMP Model Roles (Variants per Task Type)

| Role | Model | Provider (prefix) | Cost | When to Use |
|--------|-------|-------------------|------|-------------|
| **default** | big-pickle | opencode-zen | $0 (sub) | Daily driver — code generation, editing, terminal |
| **smol** | nemotron-3-ultra:free | openrouter | $0 | Fast lightweight edits, one-off commands |
| **task** | big-pickle | opencode-zen | $0 (sub) | Multi-step executions needing stable agentic behavior |
| **plan** | big-pickle | opencode-zen | $0 (sub) | Complex planning, algorithms, multi-file reasoning |
| **slow** | big-pickle | opencode-zen | $0 (sub) | Deep analysis — large context for codebases |
| **local** | Ornith-1.0-35B / bonsai-27b-q1_0 | local-llama | $0 | Zero agent only — air-gapped, OPSEC-sensitive work |

### L8.3 Agent-Level Routing Matrix (Decision Tree)

This is the definitive answer to "which tool does what." Read left-to-right with first-match priority.

```
START HERE
│
├── Is the task security-related?
│   ├── Security planning / architecture / design decisions
│   │   → Hermes cr1ms0n profile (big-pickle) — general-purpose planning
│   │
│   ├── Active scanning / recon / enumeration
│   │   → Babysitter with HexStrike MCP (via harness:call)
│   │   Gate: Approval breakpoint before scanning begins
│   │
│   ├── CVE correlation / vulnerability research
│   │   → Babysitter redteam-recon.js v1.1 (CVE-MCP integration)
│   │   → Hermes offsec profile for research synthesis
│   │
│   ├── OSINT / threat intelligence / general research
│   │   → Hermes research profile (nemotron on OpenRouter)
│   │   → Tavily MCP for web search
│   │
│   ├── Red team lab deployment / container management
│   │   → Hermes cr1ms0n profile (big-pickle)
│   │
│   │   → OMP task role (big-pickle) — stable agentic analysis
│   │
│   └── Adversarial testing / prompt injection / jailbreak research
│       → Hermes offsec profile (model diversity matters)
│       Gate: Explicit scope of work document signed
│
├── Is the task code-related?
│   │   → OMP task role (big-pickle) — fast, stable execution
│   │   Exception: Architecture-heavy code (≥500 lines) → OMP plan role (big-pickle)
│   │
│   │   → OMP task role (big-pickle) — best edit stability
│   │   Guard: Babysitter gitleaks scan after edit if secrets detected
│   │
│   │   → OMP slow role (big-pickle) — deep analysis
│   │
│   │   → OMP slow role (big-pickle) — large context for stack traces
│   │   → If runtime debugger needed: OMP task role
│   │
│   │   → OMP task role (big-pickle) — stable execution
│   │   → If TDD enforcement needed: Babysitter harness
│   │
│   ├── Architecture / design documents
│   │   → Hermes cr1ms0n (big-pickle)
│   │
│       → OMP slow role (big-pickle) — broad searches
│       → OMP smol role for quick lookups
│
├── Is the task documentation / writing?
│   ├── Technical writing (architecture docs, READMEs, reports)
│   │   → Hermes cr1ms0n profile (big-pickle)
│   │
│   ├── Blog posts / career content
│   │   → Hermes writing profile with blog-post-writing skill loaded
│   │   Post-process: stop-slop skill for AI-ism removal
│   │
│   ├── Obsidian vault notes / knowledge codification
│   │   → Hermes cr1ms0n (vault-intelligence for retrieval)
│   │   → Hermes cr1ms0n for prose-heavy entries
│   │
│   └── Session handoff documents
│       → Hermes cr1ms0n (session-start/handoff skills)
│       → Save to 80-Operations/Handoffs/
│
├── Is the task operational?
│   │   → OMP default role (big-pickle)
│   │
│   │   → OMP default role (big-pickle)
│   │
│   ├── Workflow enforcement / approval gates
│   │   → Babysitter (harness with breakpoints)
│   │
│   ├── Monitoring / observability / cost tracking
│   │   → Herdr dashboard
│   │   → Hermes cr1ms0n for analysis
│   │
│   └── Git operations / repo management
│       → OMP task role (git is terminal-native)
│
├── Is the task research / intelligence?
│   ├── Academic research (arXiv, papers)
│   │   → Hermes research profile + arxiv skill
│   │
│   ├── Market / industry research
│   │   → Hermes research profile + Tavily MCP
│   │
│   ├── Social media monitoring
│   │   → Hermes offsec for X/Twitter (xurl skill)
│   │
│   ├── RSS feed tracking
│   │   → blogwatcher skill on Hermes research
│   │
│   └── Multi-agent research (parallel queries)
│       → Hermes cr1ms0n with delegate_task (up to 3 parallel)
│
    → OMP default role (big-pickle) — general-purpose fallback
    → If context remains ambiguous: Hermes cr1ms0n for task classification
```

### L8.4 Provider Diversity Matrix

| Provider | Models Available | Cost | Use Case | Risk |
| **OCG Go** | 20 models incl. glm-5.2, kimi-k2.7, deepseek-v4, qwen3.7 | $0 ($10/mo sub) | Hermes fallbacks, emergency override | Single provider SPOF |
| **OCG Zen** | 63 models incl. GPT-5.4, Claude-Sonnet-4, Gemini-3.5 | PAYG ($16.13 buffer) | Premium on-demand only | Buffer depletion |
| **OpenRouter Free** | 27 free models | $0 | Model diversity for offsec, OMP smol | Rate limits, availability |
| **OpenRouter Paid** | All premium models | $15/mo hard limit | Emergency premium, benchmark comparisons | Budget overrun |

**Routing priority:** OCG Go → OpenRouter free → OCG Zen (buffer) → OpenRouter paid (limit)

### L8.5 Fallback Chain

When the primary provider fails (timeout, 401, rate limit):

```
Primary (OCG Go)
  ↓ fail
Secondary (OpenRouter free model)
  ↓ fail
Tertiary (OCG Zen — PAYG, use only if critical)
  ↓ fail
Fallback: Local model (if configured) or user notification
```

**Fallback implementation:**
- Hermes: `fallback_providers: ["opencode-go", "openrouter:free"]` in config.yaml
- OMP: Model role fallback chains in config.yml
- Babysitter: `--fallback` flag in harness calls

---

## L6 — Validation Gate

**Status:** 🟡 Design Complete — Implementation: P1 (next session)

### L6.1 What gitlawb.com Actually Is

Gitlawb is a **decentralized git network for AI agents** — NOT a governance rules engine. Key capabilities:

| Capability | What It Provides | Validation Use |
|------------|-----------------|----------------|
| DID identity | Cryptographic keypair per agent | Every agent action is signed and verifiable |
| UCAN delegation | Capability tokens (scoped, expiring) | Babysitter grants approval tokens for specific gates |
| Signed ref updates | Every git push cryptographically signed | Audit trail for code changes |
| Trust scores | Agent reputation based on history | Babysitter can reject low-trust agent PRs |
| MCP server (15 tools) | Git operations via agent-native API | PR review, issue sign-off, task delegation |
| GraphQL subscriptions | Real-time event streams | Validation events broadcast to all agents |
| Ref certificates | Multi-sig approval on ref updates | Code gate requires N-of-M signatures |

**Verdict:** Gitlawb is NOT a policy engine (no OPA/Rego, no rule evaluation). It IS a **cryptographic identity + audit trail layer** that Babysitter and OPA can leverage for validation.

### L6.2 Validation Gate Architecture — Three-Layer Design

```
Tool Action Requested
       │
       ▼
┌──────────────────────────────┐
│ LAYER 1: Authentication      │ ← gitlawb DID
│  - Who is this agent?        │
│  - Is the request signed?    │
│  - Is the DID known/allowed? │
└──────────┬───────────────────┘
           │ pass
           ▼
┌──────────────────────────────┐
│ LAYER 2: Authorization       │ ← OPA / policy engine
│  - Is this action allowed?   │
│  - Is it within budget?      │
│  - Is it within scope?       │
│  - Is it during allowed hrs? │
└──────────┬───────────────────┘
           │ pass
           ▼
┌──────────────────────────────┐
│ LAYER 3: Approval Gate       │ ← Babysitter workflow
│  - Does this require human?  │
│  - Needs N-of-M signatures?  │
│  - What if it's irreversible?│
└──────────┬───────────────────┘
           │ pass
           ▼
      ACTION EXECUTED
           │
           ▼
┌──────────────────────────────┐
│ AUDIT TRAIL (gitlawb)        │
│  - Signed record of:         │
│    - Who requested           │
│    - What policy was checked │
│    - Who approved            │
│    - What was done           │
│    - What was the outcome    │
```
└──────────────────────────────┘
```

---

## L10 — Memory Layer (NEW in v2.0)

**Status:** 🟡 **Implemented** — 3-tier architecture deployed via Hivemind + session hooks + consolidation cron.

### L10.1 3-Tier Architecture

The Memory Layer formalizes the ad-hoc context/memory systems into a structured 3-tier architecture:

| Tier | Name | Lifetime | Backend | Capacity | Eviction |
|------|------|----------|---------|----------|----------|
| **1** | Short-term | Session | OMP context (in-memory) | Model window (128K-1M tokens) | LRU on compact/reset |
| **2** | Working | 90 days | Hivemind SQLite (`~/.local/share/hivemind/`) | Unbounded append-only event log | Auto-promote to Tier 3 after 90d |
| **3** | Long-term | Indefinite | ChromaDB (vectors) + Neo4j (graph) + Mem0 MCP (prefs) | Indefinite with decay scoring | Prune candidate at >365d unreferenced |

### L10.2 Data Flow

```
  ┌──────────┐       ┌──────────┐       ┌───────────┐
  │  Agent   │       │ Session  │       │ Cron Job  │
  │ (OMP/    │       │ End Hook │       │ (daily)   │
  │  Hermes) │       │          │       │           │
  └────┬─────┘       └────┬─────┘       └─────┬─────┘
       │                  │                    │
       │ 1. Start task    │                    │
       ├──────────────────►                    │
       │                  │                    │
       │ 2. Load context  │                    │
       │ ┌────────────────┐                    │
       │ │ Short-term     │ ← current session  │
       │ │ (in memory)    │                    │
       │ └────────────────┘                    │
       │  │                                    │
       │  ▼ 3. Query working                   │
       │ ┌────────────────┐                    │
       │ │ Working        │ ← last N sessions  │
       │ │ (Hivemind)     │   from Hivemind    │
       │ └────────────────┘                    │
       │  │                                    │
       │  ▼ 4. Query long-term                 │
       │ ┌────────────────┐                    │
       │ │ ChromaDB       │ ← relevant         │
       │ │ Neo4j          │   vectors/graph    │
       │ │ Mem0           │   for task         │
       │ └────────────────┘                    │
       │                  │                    │
       │ 5. Execute task  │                    │
       │◄─────────────────┤                    │
       │                  │                    │
       │ 6. Task done     │                    │
       ├──────────────────►                    │
       │                  │                    │
       │                  │  7. Write events   │
       │                  │ ┌──────────────┐  │
       │                  │ │ Working:     │  │
       │                  │ │ • decisions  │  │
       │                  │ │ • failures   │  │
       │                  │ │ • summaries  │  │
       │                  │ │ → Hivemind   │  │
       │                  │ └──────────────┘  │
       │                  │                    │
       │                  │  8. Write summary  │
       │                  │ ┌──────────────┐  │
       │                  │ │ Long-term:   │  │
       │                  │ │ • embeddings │  │
       │                  │ │ → ChromaDB   │  │
       │                  │ └──────────────┘  │
       │                  │                    │
       │                  │                    │ 9. Consolidation
       │                  │                    │ ┌──────────────┐
       │                  │                    │ │ Working→LT   │
       │                  │                    │ │ • dedup      │
       │                  │                    │ │ • summarise  │
       │                  │                    │ │ • prune      │
       │                  │                    │ │ • decay      │
       │                  │                    │ │   scoring    │
       │                  │                    │ └──────────────┘
       └──────────────────┘                    │
```

### L10.3 Implementation Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `hivemind-init.sh` | Initialize SQLite schema (events, summaries, decay tables) | `80-Operations/scripts/memory/` |
| `hivemind-write.sh` | Append single event to Hivemind working store | `80-Operations/scripts/memory/` |
| `session-end-hook.sh` | OMP session-end hook — extracts decisions/failures/tokens | `80-Operations/scripts/memory/` |
| `consolidation-cron.sh` | Daily — promotes Tier 2→3, runs decay scoring | `80-Operations/scripts/memory/` |
| `decay-scoring.sh` | Weekly — ages long-term memories, archives prune candidates | `80-Operations/scripts/memory/` |

### L10.4 Integration Points

| Agent | Integration |
|-------|-------------|
| **OMP** | `--load-context` flag reads Tier 2+3 into short-term; session-end hook writes to Hivemind |
| **Hermes** | `post_task` hook writes structured events to Hivemind; `pre_task` reads working context |
| **L4 Failure Miner** | Reads failure records from Hivemind (working, 90d window) + ChromaDB (long-term, all-time) |
| **L5 Proposal Engine** | Reads pattern frequencies from ChromaDB long-term summaries |
| **Mem0 MCP** | User preference memory loaded automatically at session start |

### L10.5 Retention Policies

| Tier | TTL | Eviction | Promotion |
|------|-----|----------|-----------|
| Short-term | Session length | On compact/reset | Session-end summary → Working |
| Working | 90 days | Auto-delete after summarisation | Condensed summary → Long-term |
| Long-term | Indefinite | Prune candidate at >365d unreferenced | Cold archive before delete |

---

## L4 — Observability (UPGRADED in v2.0)

**Status:** 🟡 **Langfuse stack ready** — OMP instrumentation pending

### L4.1 Stack

| Service | Port | Purpose |
|---------|------|---------|
| Langfuse | 3000 | Dashboard + Trace UI |
| Postgres 15 | 5432 | Relational store (traces, sessions) |
| ClickHouse | 8123 | Analytics (events, costs) |
| OpenRouter | 443 | Cost analytics (external) |

### L4.2 Deployment

```bash
cd 80-Operations/infra/langfuse

# Generate secrets
export NEXTAUTH_SECRET="$(openssl rand -base64 32)"
export SALT="$(openssl rand -base64 32)"
export POSTGRES_PASSWORD="$(openssl rand -base64 16)"

# Start stack
docker compose up -d

# Verify
docker compose ps
#   langfuse-postgres   Up (healthy)
#   langfuse-clickhouse Up
#   langfuse-server     Up

# Open dashboard
echo "http://localhost:3000"
```

Create initial admin user at `/auth/signup` on first visit.

### L4.3 Instrumenting OMP

Add to `~/.omp/agent/config.yml`:

```yaml
observability:
  provider: langfuse
  endpoint: http://localhost:3000/api/public
  public_key: "${LANGFUSE_PUBLIC_KEY}"
  secret_key: "${LANGFUSE_SECRET_KEY}"
```

Keys generated from Langfuse dashboard: **Settings → API Keys → Create new**.

Every model call (all roles: default, task, plan, slow, smol) is automatically traced:
- Span per request: model, tokens, latency, error
- Trace across retries: backoff + fallback chains as sub-spans
- Cost attribution: token usage per model per agent role

Verify by running a model call and checking Langfuse dashboard for new trace.

### L4.4 Instrumenting Hermes

Add to `~/.hermes/config.yaml`:

```yaml
callbacks:
  - name: langfuse
    type: sdk
    config:
      sdk: "@langfuse/langfuse-node"
      host: http://localhost:3000
      public_key: "${LANGFUSE_PUBLIC_KEY}"
      secret_key: "${LANGFUSE_SECRET_KEY}"
      enabled: true
```

Instruments:
- Tool calls (bash, grep, edit, read) — each gets a span
- Subagent dispatches — parent-child trace from Hermes → task agent → tool
- Model completions — token count, cost estimate, response latency
- Errors — exception logging with stack trace

### L4.5 L4 Failure-Miner Integration

Langfuse traces feed directly into the L4 failure-mining pipeline:

1. Every error logged to Langfuse carries `trace_id` and `observation_id`
2. L4 failure-miner (`80-Operations/scripts/l4/failure-miner.sh`) reads Langfuse via public API:
   ```bash
   curl -s -H "Authorization: Bearer ${LANGFUSE_SECRET_KEY}" \
     "http://localhost:3000/api/public/traces?limit=50&tags=error"
   ```
3. Failure report entries include:
   ```yaml
   - trace_id: "9b4f2e..."
     observation_id: "span_8a2c..."
     model: "openrouter/gemini-2.5-pro"
     error: "rate_limit_exceeded"
     timestamp: "2026-07-19T04:12:30Z"
     cost: 0.042
   ```
4. Pipeline:
   ```
   Langfuse traces ──→ L4 failure-miner (via API)
                           │
                           ├── Groups by error type
                           ├── Correlates with config changes
                           ├── Tags affected models/providers
                           └── Writes failure report → 40-Memory/failure-reports/
                                │
                                └── L5 (proposal-engine) reads report
                                     └── Suggests rollback, retry config, or provider switch
   ```

### L4.6 URLs

| Resource | URL | Notes |
|----------|-----|-------|
| Dashboard | http://localhost:3000 | Traces, sessions, cost analytics |
| API | http://localhost:3000/api/public | REST ingestion + query |
| Auth UI | http://localhost:3000/auth/signup | First-run admin creation |
| OpenRouter Cost | _(cron)_ | `80-Operations/scripts/gateway/openrouter-cost.sh` |

### L4.7 Maintenance

**Backups:**
```bash
docker exec langfuse-postgres pg_dump -U langfuse langfuse > backup_$(date +%F).sql
```

**Log rotation (ClickHouse):**
```sql
ALTER TABLE langfuse.traces MODIFY TTL timestamp + INTERVAL 90 DAY;
```

**Restart after host reboot:**
```bash
cd 80-Operations/infra/langfuse && docker compose restart
```

---

### L6.3 Agent-Specific Validation Rules

Each agent has distinct rules it must check before acting:

#### Hermes (orchestrator)

| Rule | Check | Enforcement | Failure Mode |
|------|-------|-------------|-------------|
| Write guard | Is the target file in ~/.hermes/ or protected? | Refuse cross-profile writes | Warn and abort |
| Profile isolation | Is this task in the right profile? | If offsec task on orchestrator → warn | Route to correct profile |
| Cost guard | Does this task require OCG Zen? | If non-critical → route to OCG Go | Re-route to OCG Go |
| OPSEC check | Does the output contain secrets? | gitleaks scan before final message | Redact and warn |
| Skill audit | Is a skill loaded that matches the task? | Check skill triggers against task | Suggest skill load |

#### OMP (executor)

| Rule | Check | Enforcement | Failure Mode |
|------|-------|-------------|-------------|
| Provider prefix | Does model name have correct prefix? | Enforce `opencode-go/` for daily drivers | Route to correct prefix |
| Token waste | Is context >200K for a simple edit? | Suggest `--model smol` for small tasks | Skip suggestion if urgent |
| Write safety | Is the file a config / alias file? | Warn before overwriting | Create backup first |
| Git guard | Are there uncommitted changes? | Stash or commit before destructive ops | Block and ask |
| Secret check | Does new code contain secrets? | gitleaks on file write | Block write |

#### Goose (life admin)

| Rule | Check | Enforcement | Failure Mode |
|------|-------|-------------|-------------|
| OPSEC isolation | Is career data staying in Goose? | Verify no data leaks to Hermes context | Block cross-contamination |
| Provider gate | Is OpenRouter model working? | Test model before executing pipeline | Fall back to working model |
| File scope | Does this need access to security repos? | Restrict to ~/Github/career-ops/ | Warn and restrict |
| Sensitive content | Is the output suitable for external sharing? | Tone check, fact check | Re-draft with corrections |

#### Babysitter (workflow enforcer)

| Rule | Check | Enforcement | Failure Mode |
|------|-------|-------------|-------------|
| Approval gate | Does this step require human breakpoint? | Default deny on scanning/writing | Pause and wait |
| Scope guard | Is target in scope? | Check scope file before scanning | Block out-of-scope targets |
| gitleaks | Does output contain secrets? | Run after every write/code task | Redact and re-run |
| CVE check | Is there a known CVE for this path? | CVE-MCP lookup before exploitation | Recommend alternative |
| Parallel guard | Are parallel tasks independent? | Dependency check before spawn | Serialize dependent tasks |

### L6.4 gitlawb Integration Points

| Integration | How It Works | Component |
|-------------|-------------|-----------|
| **Agent DIDs** | Every agent gets `did:gitlawb:` identity — all actions are signed | Identify + authenticate |
| **UCAN tokens** | Babysitter issues UCAN tokens for specific gates — agent presents token to proceed | Authorization delegation |
| **Signed ref certs** | After validation gate passes, results signed and stored as git refs — immutable audit trail | Audit |
| **Trust scores** | Failed validations reduce trust score. Repeat failures trigger review | Reputation |
| **MCP tools** | Babysitter calls gitlawb MCP tools to: create signed issues, submit review verdicts, broadcast validation tasks | Execution |
| **GraphQL events** | Validation passes/failures broadcast as events — all agents stay informed | Awareness |

**Implementation order:**
1. Install gitlawb CLI (`gl`)
2. Generate DIDs for each agent (Hermes, OMP, Goose, Babysitter)
3. Configure gitlawb MCP server on offsec profile
4. Babysitter issues UCAN tokens for approval gates
5. Validation outcomes stored as signed refs in gitlawb repo

### L6.5 Alternative/Complementary Tools

Since gitlawb is NOT a policy engine, pair it with one of these for rule evaluation:

| Tool | Type | Integration with gitlawb | Complexity |
|------|------|------------------------|------------|
| **OPA** (Open Policy Agent) | Policy engine (Rego) | gitlawb DID identifies agent → OPA evaluates policy per-agent | High — full OPA deployment |
| **systemprompt-core** | MCP governance runtime | gitlawb as identity provider, systemprompt as policy enforcer | Medium — Rust binary |
| **Microsoft Agent Governance Toolkit** | Runtime policy for agent frameworks | Directly integrates with Python agent frameworks | Medium — Python SDK |
| **Babysitter-only** (no external policy engine) | Workflow gating | All rules in Babysitter JS processes — simplest | Low — already have Babysitter |

**Recommendation:** Start with **Babysitter-only** (Layer 3 gate) for Phase 1, then add **gitlawb DIDs** (Layer 1) and choose a policy engine (Layer 2) based on which OWASP Agentic Top 10 risks are most pressing.

---

## L4 — Failure Mining

**Status:** 🔴 Design Complete — Implementation: P2

### L4.1 Data Sources

Every failure event in the stack gets collected and classified. These are the source signals:

| Source | What It Captures | Current State |
|--------|-----------------|---------------|
| **Hivemind hooks** | Session events — tool errors, model errors, decision points | ✅ Active (MCP server) |
| **Context-mode capture** | Auto-indexed session content — error messages, stack traces, rejected approaches | ✅ Active (26 event categories) |
| **Hermes tool logs** | Tool call successes/failures, timeouts, content filters | 🟡 Passive (in session DB) |
| **OMP execution logs** | Code execution results, error exits, LSP failures | 🟡 In OMP cache (~/.omp/) |
| **Babysitter journals** | Process step outcomes, gate passes/failures | 🟡 In ~/.a5c/journals/ |
| **Hermes gateway logs** | Provider errors (401, 404, 429, timeout) | ❌ Not collected |
| **Provider API responses** | Rate limit headers, error codes, model failures | ❌ Not collected |
| **Model response quality** | Refusals, hallucinations, format errors | ❌ Not collected (hard to detect) |

### L4.2 Pipeline Design

```
COLLECT               CLASSIFY              ANALYZE              REPORT
────────              ────────              ────────              ──────

Hivemind events ──►  ┌─────────────┐       ┌──────────────┐      ┌────────────────┐
                     │ Category    │       │ Frequency    │      │ failure-report │
Context-mode   ──►   │ - tool      │       │ per agent    │──►   │  - date        │
session DB           │ - model     │       │ per tool     │      │  - category    │
                     │ - config    │       │ per provider │      │  - failure #N  │
Tool error     ──►   │ - workflow  │       │              │      │  - source      │
logs                 │ - auth      │──►    │ Pattern      │      │  - frequency   │
                     │ - resource  │       │ detection    │      │  - impact      │
Babysitter     ──►   │ - timeout   │       │ - same error │      │  - root cause  │
journals             │ (see L4.3)  │       │   N times    │      │  - trend       │
                     └─────────────┘       │ - error      │      │  - proposal    │
Provider API   ──►                         │   cascade    │      │    ref         │
logs                                       │ - trend      │      └────────────────┘
                     ╔═══════════════╗     │   (up/down)  │             │
                     ║ Root Cause    ║     └──────────────┘             ▼
                     ║ Analysis      ║             │            ┌────────────────┐
                     ║ - direct cause║             │            │ SENT TO        │
                     ║ - contrib.    ║◄────────────┘            │ PROPOSAL ENGINE│
                     ║   factors     ║                          │ (L5)           │
                     ║ - fix cmd     ║                          └────────────────┘
                     ╚═══════════════╝
```

### L4.3 Failure Classification Taxonomy

```
tool/    
  ├── timeout          — Tool took longer than timeout budget
  ├── parse-error      — Tool returned unparseable output
  ├── not-found        — Binary / file not found
  ├── perm-denied      — Permission error (file, network, sudo)
  └── unexpected       — Exit code ≠ 0, no known error pattern

model/
  ├── rate-limit       — 429 from provider
  ├── auth-fail        — 401/403 from provider
  ├── model-not-found  — 404 from provider (e.g. nemotron guardrail)
  ├── empty-response   — Model returned empty content (reasoning overhead)
  ├── refusal          — Model refused the request
  └── timeout          — Provider didn't respond in time

config/
  ├── yaml-parse       — YAML/JSON parse failure (e.g. args as string)
  ├── env-missing      — Required env var not set
  ├── mcp-args         — MCP server startup args wrong format
  └── key-hardcoded    — API key literal in config (security)

workflow/
  ├── gate-blocked     — Babysitter gate stopped execution
  ├── scope-violation  — Task tried to operate outside scope
  ├── parallel-race    — Parallel tasks conflicted on resource
  └── content-filter   — Hermes/content guardrail blocked action

auth/
  ├── key-expired      — API key no longer valid
  ├── key-invalid      — Key format doesn't match provider
  ├── rate-limit       — Per-key rate limit hit
  └── guardrail        — OpenRouter/content guardrail blocked

resource/
  ├── disk-full        — Out of disk space
  ├── memory-exhausted — OOM
  ├── vram-exhausted   — CUDA OOM (local models)
  └── port-in-use      — Required port already bound

timeout/
  ├── network          — curl/HTTP request timed out
  ├── tool             — Hermes tool execution timed out
  └── model            — Model inference took too long
```

### L4.4 Automated Collection Script

```
Script: ~/.hermes/profiles/orchestrator/scripts/failure-miner.sh
Schedule: cronjob daily
```

```bash
#!/bin/bash
# Collect failure events from all sources and output structured report

# 1. Collect Hivemind session errors (last 24h)
hivemind events --type error --since "24h ago" | jq -c '{source:"hivemind", type:.type, agent:.agent, message:.message, timestamp:.timestamp}'

# 2. Collect recent context-mode events
context-mode session search --query "error OR fail OR timeout" --limit 50 | jq -c '{source:"context-mode", query:.query, matches:.matches}'

# 3. Check Hermes gateway logs for provider errors
journalctl --user -u hermes* --since "24 hours ago" --no-pager | grep -iE "(401|403|404|429|timeout|error|fail)" | tail -50

# 4. Check Babysitter failed runs
find ~/.a5c/journals/ -name "*.json" -mtime -1 | while read journal; do
  cat "$journal" | grep -E '"result":"fail"' | jq -c '{source:"babysitter", workflow:.workflow, step:.step, error:.error}'
done

# 5. Output summary
echo "=== Failure Mining Report $(date -I) ==="
# ... aggregation logic
```

### L4.5 Output Format

Each failure mining run produces a structured report:

```json
{
  "report_id": "fm-2026-06-20",
  "date": "2026-06-20",
  "period": "24h",
  "total_failures": 12,
  "classes": {
    "tool": { "count": 4, "top": "timeout (2)" },
    "model": { "count": 5, "top": "auth-fail (3)" },
    "config": { "count": 1, "top": "mcp-args (1)" },
    "workflow": { "count": 1, "top": "scope-violation (1)" },
    "auth": { "count": 1, "top": "guardrail (1)" }
  },
  "trending": [
    { "pattern": "nemotron-3-ultra 404", "count": 3, "action": "P0 — fix OpenRouter guardrail" },
    { "pattern": "OMP provider prefix missing", "count": 2, "action": "P1 — add prefix enforcement" }
  ],
  "new_issues": [
    { "pattern": "Horizon MCP timeout", "count": 1, "first_seen": "2026-06-20", "action": "Disable Horizon MCP" }
  ]
}
```

---

## L4-S: Static Code Mining — Code Archaeology Concept

**Status:** 🔵 Concept Note — No implementation planned
**Reference:** [Code Archaeology](https://code-archaeology.teamoperator.red/) by Maleick

### Purpose

Where L4 (Failure Mining) collects *runtime* failures from agent execution, L4-S mines *static* code debt: dead code, legacy legacy shims, circular dependencies, weak types, duplication, and error-handling slop. They're complementary — one catches what breaks at runtime, the other catches what makes the codebase fragile and slow to change.

### Why Concept, Not Tool

The Code Archaeology tool (`opencode-code-archaeology` npm package) requires OpenCode or Codex as the host runtime. Since this stack uses Hermes + OMP (not OpenCode/Codex), the npm tool is not directly usable. However, the **methodology** is valuable and can be replicated:

### Integration Modes (Conceptual)

#### Mode A: Triggered — Pre-Refactor Health Check

Run before any significant refactor or type consolidation. A subagent surveys the target repo and writes a `.archaeology/`-style report to the vault. The report gates whether the refactor proceeds.

```
Trigger: User says "refactor X module" or "consolidate Y types"
  → dispatches survey subagent (hermes orchestrator, delegate_task)
  → survey produces report in vault
  → report flags: dead code, cycles, weak types relevant to scope
  → human reviews report → proceeds or adjusts scope
```

Best fit: L6 (Validation Gate) — the survey becomes a validation pass before the refactor gate.

#### Mode B: Sequence — Periodic Health Scan (Cron)

A cronjob runs a reduced survey on a schedule (e.g., every N sessions or weekly). Scans only changed files (git diff against last survey). Reports trends: is the codebase getting healthier or accruing more debt?

```
Schedule: weekly, or after every 10th session with code changes
  → git diff --stat to find changed files
  → survey: dead code, type issues, circular deps (scope: changed files)
  → compare against last survey → trend line
  → output: "3 new dead exports, 1 cycle introduced" or "clean — no new debt"
  → if debt increases > threshold → flag for human review
```

Best fit: L4 (Failure Mining) extension — add a cron-based collection source alongside the runtime failure collector.

#### Mode C: Architecture — 10-Layer Sibling to L4

Add L4-S as a permanent sibling to L4 in the 10-layer stack:

| Layer | Name | Purpose | Data Source |
|-------|------|---------|-------------|
| L4 | Failure Mining | Runtime error patterns | Hivemind hooks, session DB, tool logs |
| L4-S | Static Code Mining | Codebase debt trends | Git history, LSP diagnostics, knip/madge survey |
| L5 | Proposal Engine | Improvement proposals | L4 + L4-S output combined |

L4-S feeds the same Proposal Engine (L5) as L4, so code debt proposals compete for priority with runtime failure fixes on the same impact/effort matrix. This prevents runtime fires from permanently drowning out code health.

### Tooling Notes (No New Dependencies)

Since the stack doesn't have OpenCode/Codex, replicate Code Archaeology's phases using existing tools:

| Phase | Code Archaeology Tool | Hermes/OMP Equivalent |
|-------|----------------------|----------------------|
| Dead code | `knip` | `npx knip` (terminal/OMP) |
| Legacy shims | Custom grep | `grep -r "deprecated\|legacy\|@obsolete"` |
| Circular deps | `madge` | `npx madge --circular` |
| Type catalog | `tsc --noEmit` | `npx tsc --noEmit` (already in OMP) |
| Duplication | `jscpd` | `npx jscpd` |
| Error handling | Custom grep | `grep -E "try\s*\{"` pattern analysis |

All are `npx`-runnable — zero install, zero config management.

### Decision Record

- **Concept noted:** 2026-06-20, S089
- **Not building now:** No candidate repo has sufficient code volume to justify the overhead
- **Revisit trigger:** When a repo exceeds ~50 files with active development, or when a refactor session reveals unexpected structural debt
- **10-layer integration:** L4-S documented here for when the trigger fires

---

## L5 — Proposal Engine

**Status:** 🔴 Design Complete — Implementation: P2

### L5.1 Input: Failure Reports from L4

The proposal engine consumes structured failure reports and generates actionable improvement proposals. Each L4 failure report produces 0-N proposals.

### L5.2 Proposal Types

| Type | Example | Impact Level | Effort Level |
|------|---------|-------------|-------------|
| **Config fix** | MCP args string → list | High | Low |
| **Tool replacement** | Replace Horizon MCP with nothing (disable) | Medium | Low |
| **Process change** | Add provider prefix check before OMP launch | High | Medium |
| **Automation** | Auto-collect failure data daily | Medium | Medium |
| **Training/documentation** | Write gitlawb MCP setup guide | Low | Low |
| **Infrastructure** | Deploy OPA as central policy engine | High | High |

### L5.3 Proposal Generation Pipeline

```
┌──────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────┐
│ L4       │───►│ Categorize   │───►│ Generate     │───►│ Rank by      │───►│ Surface  │
│ Failure  │    │ by impact    │    │ proposals    │    │ impact/effort │    │ to user  │
│ Report   │    │ - P0: blocks │    │ - template   │    │ - P0: do now  │    │ - report │
│          │    │ - P1: breaks │    │ - custom     │    │ - P1: plan    │    │ - suggest│
│          │    │ - P2: minor  │    │ - multi-fix  │    │ - P2: backlog │    │ - auto-  │
│          │    │ - P3: nice   │    │              │    │ - P3: someday │    │   apply  │
└──────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────┘
```

### L5.4 Proposal Template

Each proposal follows a standard format for machine and human readability:

```yaml
---
proposal_id: "prop-2026-06-20-001"
title: "Fix OpenRouter nemotron-3-ultra guardrail 404"
status: "pending"  # pending | accepted | rejected | implemented | superseded
source_report: "fm-2026-06-20"  # L4 report that triggered this
classification:
  impact: "P0 — blocks research profile"
  effort: "Medium — config change + test"
  category: "config/model"
description: >
  Research profile gets HTTP 404 on nvidia/nemotron-3-ultra-550b-a55b:free.
  OpenRouter guardrail setting blocking the model.
recommended_fix: |
  1. Verify guardrails at https://openrouter.ai/settings/privacy
  2. If still blocked, switch to openrouter/free (auto-routes)
  3. Test research profile: `hermes -p research -c "test connection"`
auto_apply: false  # true = safe to auto-apply (e.g. config change)
dependencies: []  # proposal IDs that must be done first
alternatives:
  - model: "openrouter/deepseek/deepseek-v4-flash:free"
    cost: "free"
    effort: "already available"
  - model: "openrouter/qwen/qwen3-coder:free"
    cost: "free"
    effort: "already available"
---
```

### L5.5 Ranking Matrix

| Quadrant | High Impact | Low Impact |
|----------|-------------|------------|
| **Low Effort** | **DO FIRST** | **Nice-to-have** |
| | P0 config fixes | Add tests |
| | Switch broken models | Clean up docs |
| | Fix security issues | Minor UX tweaks |
| **High Effort** | **PLAN** | **BACKLOG** |
| | Deploy OPA | Rewrite component |
| | Sandbox per profile | New feature |
| | Full failure automation | Migration project |

**Formula:** `priority = impact_score / effort_score`
- impact_score: 5 (blocks all work) → 1 (minor annoyance)
- effort_score: 5 (days of work) → 1 (minutes)

**Thresholds:**
- ≥3.0 → P0 — do now
- 1.5–3.0 → P1 — plan this session
- 0.5–1.5 → P2 — next session
- <0.5 → P3 — backlog

### L5.6 Auto-Apply Rules

Some proposals are safe to auto-apply without human review:

| Auto-apply Condition | Examples | Safety Check |
|----------------------|----------|-------------|
| Config syntax fix | MCP args string → list | Validate YAML after change |
| Model switch to known-working | nemotron → qwen3.7:free | Test model responds 200 |
| Disable broken component | Horizon MCP disabling | Confirm no essential tool depends on it |
| Pure documentation | Add known issue to handoff | No change to execution |

**Never auto-apply:**
- Changes to provider API keys
- Changes to routing matrices
- Changes to profile definitions
- Any change that could break a production process
- Changes requiring sudo or system-level modification

### L5.7 Proposal Lifecycle

```
DISCOVERED (from L4)
    │
    ▼
PENDING (awaiting review)
    │
    ├── ACCEPTED → assigned to session plan
    │   │
    │   ├── IMPLEMENTED → mark done, archive
    │   │
    │   └── VERIFIED → confirm fix works, close
    │
    ├── REJECTED → record why, archive
    │
    └── SUPERSEDED → replaced by newer proposal, link to new ID
```

---

## L7 — Versioning & Rollback

**Status:** 🟡 Partial — git-backed rollback exists but is manual.

This layer is covered by existing git workflows and the Babysitter event-sourced journaling. Full design deferred until L4-L6 implementation produces enough failure data to justify it.

Current capabilities:
- All agent configs are git-tracked (`.hermes/config.yaml`, per-profile configs)
- Babysitter journals are event-sourced — full replay capability
- Context-mode session DB retains historic state
- **Missing:** Automated rollback when a config change causes failures (L4 would detect, L5 would propose, but no L7 automation yet)

---

## L9 — Benefit Measurement

**Status:** 🔴 Not Designed

**Intended purpose:** Measure whether changes from L5 proposals actually improve outcomes. Track metrics like:
- Failure rate before/after fix (L4 data)
- Token savings from compression changes
- Task completion time before/after model roster changes
- User satisfaction (implicit: fewer corrections → better routing)

**Deferred until L4 produces enough baseline data.**

---

## L10 — Weight Update

**Status:** 🔴 Not Designed

**Intended purpose:** Automatically adjust routing weights, model selection, and compression settings based on L9 measurements. Full reinforcement learning loop.

**Deferred indefinitely — requires L4, L5, L6, L7, and L9 operational first.**

---

## Implementation Roadmap

```
Session    Layer    Scope
─────────────────────────────────────────────────
THIS DOC   L8       ✅ Routing matrix documented
           L6       Design — Babysitter-first gates, gitlawb DIDs later
           L4       Design — collection pipeline built
           L5       Design — proposal templates and lifecycle

Next       L6       Implement Babysitter validation rules as processes
session    L4       Deploy failure-miner.sh as daily cronjob
P0 tasks   L4       Fix research profile guardrail (nemotron)
           L6       Install gitlawb CLI, generate agent DIDs

Next+1     L4       Classify 7 days of failure data
session    L5       Generate first proposal set from L4 data
P1 tasks   L6       Wire Babysitter gates to gitlawb DIDs

Q3         L7       Design automated rollback
           L9       Design benefit measurement
           L10      Discuss weight update feasibility
```

---

## Appendix A: L8 Routing Matrix Quick Reference

Download/print version — short form:

| You Want To... | Tool | Profile/Model | Provider |
|---------------|------|---------------|----------|
| Plan architecture | Hermes cr1ms0n | big-pickle | OCG Zen |
| Write code | OMP task | big-pickle | opencode-zen |
| Edit files | OMP task | big-pickle | opencode-zen |
| Debug code | OMP slow | big-pickle | opencode-zen |
| Run recon | Babysitter | hexstrike MCP | internal |
| Research CVE | Babysitter/Hermes offsec | CVE-MCP | offsec profile |
| Research threats | Hermes offsec | deepseek-v4-flash:free | OpenRouter |
| Write docs | Hermes cr1ms0n | big-pickle | OCG Zen |
| Apply jobs | Hermes cr1ms0n | big-pickle | OCG Zen |
| Sysadmin | OMP default | big-pickle | opencode-zen |
| Code review | OMP slow | big-pickle | opencode-zen |
| Quick command | OMP smol | nemotron-3-ultra:free | openrouter |
| Complex task | OMP plan | big-pickle | opencode-zen |
| **Zero agent** (local-only) | Zero | local-ornith / local-bonsai | local-llama@:8081 |

## Appendix B: gitlawb.com Integration Checklist

- [ ] Install gitlawb CLI: `curl -fsSL https://gitlawb.io/install.sh | sh`
- [ ] Generate agent DIDs: `gl identity new --type ed25519` for Hermes, OMP, Goose, Babysitter
- [ ] Configure gitlawb MCP on offsec profile: add `mcp_servers > gitlawb` entry
- [ ] Create validation-repo for audit trail: `gl repo create azrael-validation`
- [ ] Wire Babysitter to issue UCAN tokens per gate
- [ ] Test: Babysitter action produces signed ref in validation repo
- [ ] Document per-agent DID and scope in master context

## Appendix C: Known Issues Referenced

From upstream audits (see `azrael-handoff-S082.md` and `skills-mcp-audit.md`):

| Issue | Layer | Priority | Proposal |
|-------|-------|----------|----------|
| Research profile OpenRouter 404 | L8 | P0 | Switch nemotron → qwen3.7:free or openrouter/free |
| Offsec config has hardcoded TAVILY_API_KEY | L6 | P0 | Replace with `os.environ/TAVILY_API_KEY` |
| Offsec cve-mcp args as string not list | L4 | P1 | Fix YAML `args` format |
| Goose nemotron model likely broken | L8 | P1 | Test with working model |
| `.zshenv` has literal API keys | L6 | P1 | Move to `~/.config/azrael-secrets/env` (600) |
| Horizon MCP redundant | L8 | P2 | Disable MCP server |
| AgentView → Herdr bridge not built | L5 | P2 | Deferred — not enough failure data yet |
| Session files with masked key patterns | L6 | P2 | Purge old sessions |
| Codex / pi-agent-setup stale skills | L6 | P2 | Remove from skill library |
| SSH/GPG not sandboxed per profile | L6 | P3 | bwrap config per profile |

---

## S140 Addendum — Current Routing Tables (Supersedes L8.1 / L8.2 / L8.4 / Appendix A)

*Authoritative as of 2026-07-19. Sourced from `~/.omp/agent/config.yml`, `~/.hermes/profiles/cr1ms0n/config.yaml`, and live service checks.*

| Profile | Model | Provider | Base URL | Cost | Context | Best For |
|---------|-------|----------|----------|------|---------|----------|
| **cr1ms0n** (main) | big-pickle | OCG Zen | `opencode.ai/zen/v1` | $0 (sub) | varies | Daily driver — planning, coding, orchestration, writing |
| **offsec** | deepseek-v4-flash:free | OpenRouter | `openrouter.ai/api/v1` | $0 | varies | Red team, prompt injection, jailbreak research |
**Note:** `glm-5.2` previously used as orchestrator/plan model but retired in S139 due to reliability issues. Replaced by `minimax-m3` (OCG Go) then `opencode-zen/big-pickle`. No active role currently uses glm-5.2.

| Role | Model | Provider (prefix) | Cost | When to Use |
|--------|-------|-------------------|------|-------------|
| **default** | big-pickle | opencode-zen | $0 (sub) | Daily driver — code generation, editing, terminal |
| **smol** | nemotron-3-ultra:free | openrouter | $0 | Fast lightweight queries, one-off commands |
| **task** | big-pickle | opencode-zen | $0 (sub) | Multi-step executions, editing, testing |
| **plan** | big-pickle | opencode-zen | $0 (sub) | Complex planning, algorithms, multi-file reasoning |
| **slow** | big-pickle | opencode-zen | $0 (sub) | Deep analysis, large context, code review |
| **local** (Zero only) | Ornith-1.0-35B / bonsai-27b-q1_0 | local-llama@:8081 | $0 | Zero agent — air-gapped, OPSEC-sensitive work |

| **Fallback chains (from `~/.omp/agent/config.yml`):**
- `default`: opencode-zen/big-pickle → openrouter/ring-2.6-1t → openrouter/deepseek-v4-pro
- `task`: opencode-zen/big-pickle → openrouter/ring-2.6-1t
- `smol`: openrouter/nemotron-3-ultra:free → opencode-zen/big-pickle
- `plan`: opencode-zen/big-pickle → openrouter/ring-2.6-1t → openrouter/deepseek-v4-pro
- `slow`: opencode-zen/big-pickle → openrouter/ring-2.6-1t

**OMP skills loaded** (`~/.omp/agent/skills/`): caveman, ponytail, graphify, read-the-docs, test-driven-development, using-git-worktrees, finishing-a-development-branch.

**OMP approval mode:** `yolo` — auto-approve edits, but approval gate still fires for destructive ops (rm -rf, sudo, etc.) via built-in `bash` tool guards.

**OMP dispatch pattern (S139 standard):**
```bash
omp --model opencode-zen/big-pickle -p '<goal>' --auto-approve
```

### S140.3 Provider Diversity Matrix (L8.4 supersede)

| Provider | Models Available | Cost | Use Case | Risk |
|----------|-----------------|------|----------|------|
| **OCG Zen (opencode-zen)** | 27 models incl. big-pickle, opus-4.6, sonnet-4, gpt-5.4 | $0 ($10/mo sub for big-pickle) | Primary — Hermes cr1ms0n & OMP daily driver | Buffer depletion for premium models |
| **OCG Go (opencode-go)** | 22 models incl. minimax-m3, kimi-k3, kimi-k2.7-code, deepseek-v4-pro | $0 ($10/mo sub) | Hermes fallbacks, Zero overflow | Single provider SPOF |
| **OpenRouter Free** | 7 models (nemotron:free, deepseek-v4-flash, etc.) | $0 | Model diversity for offsec/research | Rate limits, availability |
| **OpenRouter Paid** | All premium models | $20/mo hard limit | Emergency premium, benchmarks | Budget overrun |
| **OpenGateway (opengateway)** | 2 models (nemotron:free, DeepSeek-V3.2) | $0 | gitlawb-integrated routing | New provider, lower confidence |
| **Local LLM (llama.cpp)** | ornith-1.0-35b-Q4_K_M (35B, 66K ctx) | $0 | Air-gapped, OPSEC-sensitive, no internet | Hardware-bound, no fallback |

**Routing priority:** OCG Zen (big-pickle) → OpenRouter free → OpenGateway → OCG Go → OpenRouter paid (limit) → Local LLM (Zero only)

### S140.4 Appendix A — Quick Reference (supersede)

| You Want To... | Tool | Model | Provider |
|----------------|------|-------|----------|
| Plan architecture | Hermes cr1ms0n | big-pickle | opencode-zen |
| Write code (multi-file) | OMP task | big-pickle | opencode-zen |
| Edit files (single-file) | OMP task | big-pickle | opencode-zen |
| Quick command | OMP smol | nemotron-3-ultra:free | openrouter |
| Debug code (deep) | OMP slow | big-pickle | opencode-zen |
| Code review | OMP slow | big-pickle | opencode-zen |
| Complex plan | OMP plan | big-pickle | opencode-zen |
| Sysadmin | OMP default | big-pickle | opencode-zen |
| Research threats | Hermes offsec | deepseek-v4-flash:free | openrouter |
| CTF/red team | Hermes offsec | deepseek-v4-flash:free | openrouter |
| Vault notes | Hermes cr1ms0n | big-pickle | opencode-zen |
| Handoffs | Hermes cr1ms0n | big-pickle | opencode-zen |
| Quick CLI tasks | Zero | local-ornith | local-llama@:8081 |
| Air-gapped / OPSEC | Zero | local-ornith/bonsai | local-llama@:8081 |
| Escalation (rare) | Hermes cr1ms0n | big-pickle | opencode-zen |
### S140.5 L3.5/L4 Helper — Local 35B Ornith Role

The local 35B Ornith is wired in OMP and now also accessible as a standalone endpoint. Two integration paths:

**Path A: Zero agent routes to local LLM (configured)**
- Zero activeProvider: `local-ornith` → `http://localhost:8081/v1` with model `ornith-1.0-35b`
- Use Zero for: sanitizer, redaction, one-off local queries, air-gapped work
- OMP does NOT use local models — all roles route through opencode-zen/big-pickle

**Path B: LDR (local-deep-research) as dedicated local research harness (S140 recommended, ✅ S147 verified)**
- **Location:** `~/Tools/venvs/ldr/`
- **Venv:** `source ~/Tools/venvs/ldr/bin/activate`
- **Config:** `source ~/Tools/venvs/ldr/env.sh`
- **Provider:** `custom_openai_endpoint` → `http://127.0.0.1:8081/v1`
- **Model:** Ornith-1.0-35B (via llama.cpp server on port 8081)
- **Use case:** Local agentic research — no internet, no data exfil. Runs 10-20 LLM calls per research query with multi-iteration deep search.
- **Status:** Verified working (S147) — used for offline research tasks, air-gapped analysis, and sensitive investigations where external API calls are prohibited.
- **Note:** ~95% SimpleQA on RTX 3090 with Qwen3.6-27B (similar tier to Ornith 35B per benchmarks). LDR handles the agentic loop; the local LLM endpoint serves inference.

### S140.7 Model Architecture — Verified (S140 reality check)

From `config.json` of `deepreinforce-ai/Ornith-1.0-35B`:
- **Architecture:** `qwen3_5_moe` (Qwen 3.5 MoE base, post-trained for agentic coding)
- **Total params:** 35B
- **Active params per token:** ~3B (8 of 256 experts)
- **Hidden layers:** **40** (not 65 as S140 originally estimated)
- **Attention:** Gated Delta Net hybrid (linear + full attention mix, like Qwen3.5-35B-A3B)
- **Context:** 256K native
- **Experts:** 256 total, 8 active per token
- **Vision encoder included** (vision_config block) — adds ~1.4 GB VRAM if loaded

**Current llama-server config (`~/.config/systemd/user/llama-server.service`):**
```
--n-gpu-layers 10 --ctx-size 65536 --no-kv-offload --chat-template chatml --parallel 1
```
- 10/40 layers on GPU = 25% offload
- 65K context, KV cache in fp16 (not quantized)
- `--no-kv-offload` keeps full KV cache in VRAM (expensive at 65K)
- No `-ncmoe` flag set → default MoE offload (catastrophic on 8GB per benchmarks)

**Measured performance (S140):**
- User: 18.26 t/s prompt-eval, 2-3 t/s generation (real workload, long context)
- S140 curl test: 0.03 t/s on a 10-token completion (different metric, cold start)
- Conclusion: 2-3 t/s is the real generation rate with current config — well below the 30-40 t/s the model tier can deliver with proper tuning

### S140.8 Recommended Config — S140 Research Output

**The single most impactful change: add `--n-cpu-moe` (or `-ncmoe`) flag.** Per dev.to/Medium benchmarks on RTX 3070 Ti 8GB with Qwen3.5-35B-A3B (same architecture family, same Q4_K_M tier):

| `--n-cpu-moe` | tok/s | VRAM | vs default |
|---------------|-------|------|------------|
| no flag (current) | 8.7 | 7.8 GB | baseline |
| 35 | 27.5 | 4.3 GB | 3.2x |
| 30 | 32.5 | 5.6 GB | 3.7x |
| **25** | **40.9** | **6.9 GB** | **4.7x** |
| 23 | 43.8 | 7.4 GB | 5.0x |
| 21 | 38.6 | 7.8 GB | 4.4x |
| 19 | 19.8 | 7.8 GB | 2.3x (collapse) |

**Target for RTX 3070 8GB: `-ncmoe 25`** (or whatever lands at 6.5-7.0 GB VRAM with 800MB headroom).

**Secondary changes:**
1. `--n-gpu-layers 99` (was 10) — push as many layers as fit, with `-ncmoe` offloading experts
2. `--cache-type-k q8_0 --cache-type-v q8_0` — quantize KV cache (saves ~30-50% VRAM at 16K+ context)
3. `--ctx-size 16384` (was 65536) — Ornith/LDR queries rarely need 65K, 16K saves KV cache VRAM
4. Drop `--no-kv-offload` — let KV cache spill to RAM at long contexts
5. Add `--flash-attn on` (already on) and `--parallel 1` (already 1) — both already correct
6. **Don't load mmproj** — text-only Ornith saves ~1.4 GB vision encoder VRAM

**Proposed service file (`~/.config/systemd/user/llama-server.service`):**
```
ExecStart=/home/ForeverLX/.local/bin/llama-server \
  --model /home/ForeverLX/Tools/ai/local-models/ornith-1.0-35b-Q4_K_M.gguf \
  --host 127.0.0.1 --port 8081 \
  --ctx-size 16384 --n-gpu-layers 99 \
  --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --n-cpu-moe 25 \
  --chat-template chatml --parallel 1
```

**Expected result (extrapolating from 3070 Ti benchmarks to 3070 — slightly lower bandwidth, ~90% of the speed):**
- 30-40 t/s generation (vs 2-3 t/s current) — 10-15x improvement
- 7.0-7.5 GB VRAM used
- 16K context (plenty for LDR and OMP queries)
- 256K context still possible if you drop ncmoe to 19 (19.8 t/s) — not recommended

### S140.9 Alternative Models Worth Considering

| Model | Params | Active | Quant | VRAM | Tok/s on 8GB | Quality | Notes |
|-------|--------|--------|-------|------|--------------|---------|-------|
| **Ornith-1.0-35B (current)** | 35B MoE | ~3B | Q4_K_M | 20 GB | 2-3 → 30-40 with ncmoe | Strong coding (state-of-art agentic coding benchmarks) | Best for code/agentic; SOTA on Terminal-Bench 2.1 |
| **Qwen3.5-35B-A3B** | 35B MoE | ~3B | Q4_K_M | 20.5 GB | 27-43 with ncmoe | General + coding | Same architecture family; broader benchmark coverage |
| **Qwen3.6-35B-A3B** | 35B MoE | ~3B | UD-Q4_K_XL | 22 GB | 22-30 (slower) | Best in tier | Hybrid attention; ~30% slower than 3.5; more capable |
| **Qwen3.5-9B** | 9B Dense | 9B | Q4_K_M | 6.0 GB | 54-58 | Top sub-10B (AI Analysis Index) | Fits fully in VRAM; faster, less capable |
| **Ornith-1.0-9B** | 9B Dense | 9B | Q4_K_M | 6.0 GB | ~55 | Strong coding | 9B dense version of Ornith; smaller, faster |
| **DeepSeek R1 Distill 8B** | 8B Dense | 8B | Q4_K_M | 5.8 GB | 50-60 | Best reasoning in tier | Reasoning specialist |

**Recommendation by use case (S140):**
- **Coding / agentic work (current focus for Ornith):** Keep Ornith-1.0-35B with the S140.8 config
- **General chat / fast responses:** Qwen3.5-9B (54 t/s, full VRAM fit, top sub-10B quality)
- **Reasoning-heavy:** DeepSeek R1 Distill 8B or Qwen3.6-35B-A3B
- **Quality over speed:** Qwen3.6-35B-A3B at UD-Q4_K_XL (slower but most capable)

**Qwen3.5-9B as a companion model:** Since it fits fully in 8GB VRAM (6.0 GB at Q4_K_M), it could run as a second concurrent model — fast tier for OMP smol/local-llama-fast, with Ornith-35B staying for deep work. Would need vLLM or a second llama-server instance. Not recommended yet (adds complexity, no current trigger).

### S140.10 L4/L5 Integration — Failure Mining Use Case

With LDR + Ornith at 30-40 t/s, the L4 Failure Mining layer becomes viable for offline analysis:
- Mine `~/.omp/logs/` and `~/.omp/agent/agent.db` locally
- No data exfil
- Classify failures against the L4.3 taxonomy (tool/model/config/workflow/auth/resource/timeout)
- Output structured `fm-YYYY-MM-DD.json` for L5 proposal engine

Ponytail: this is the *only* L4 use case where local LLM beats cloud (privacy + offline). Keep cloud for the rest.

### S140.6 S046 Decision Entry — Supersession

The S046 decision entry in `~/Documents/ai-lab-vault/40-Memory/azrael-decisions.md` says:

> Local LLM base model | Qwen3-4B-Instruct via Ollama | Locked S046. Best tool-calling benchmarks in 3B-7B range, fits 4GB VRAM at Q4_K_M, strong JSON schema adherence. Ollama decoupled — accessible to any future project independently.

**S140 status:** SUPERSEDED. The 35B Ornith (Qwen-class base, ~Llama-3-70B tier per benchmarks) is the real deployment, not Qwen3-4B. Ollama was decoupled but llama.cpp replaced it. S046 entry should be updated to reflect:
- Model: ornith-1.0-35b-Q4_K_M via llama.cpp @ 127.0.0.1:8081
- Wired in OMP as `local-llama` provider
- Role: sanitizer + air-gap + L4 helper + OPSEC-sensitive
- Not Qwen3-4B — that was a placeholder

