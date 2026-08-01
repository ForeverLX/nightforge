# Existing Tools Gap Audit — 6 Architecture Gaps

**Date:** 2026-07-19  
**Scope:** Checked pip site-packages, ~/.local/bin, ~/.cargo/bin, Docker configs, systemd services, Hermes/OMP plugins, K3s/kube configs, nginx, npm cache, system binaries.

## 1. Gateway / API Proxy (LiteLLM, Portkey, Helicone, nginx+ML)

### Already covered?
**NO** — completely missing.

### What exists
| Tool | Location | Role |
|------|----------|------|
| **nginx** | `/etc/nginx/conf.d/dradis.conf` | Plain SSL termination + proxy_pass to `127.0.0.1:8080`. No ML routing, no model fallback, no key management. |
| Hermes `gateway_timeout` | `~/.hermes/config.yaml` | A client-side timeout setting — NOT a gateway. |

### What's missing
- **LiteLLM**: Not installed anywhere (no pip, no binary, no Docker)
- **Portkey**: Not installed
- **Helicone**: Not installed
- **OpenRouter SDK**: Only the API key is present in `.env` — no local gateway
- **Model fallback/routing**: Hermes config uses `opencode-go` provider directly — no proxy layer for failover, rate limiting, or key rotation

> **Result:** The agent talks directly to provider APIs. There is no gateway abstraction for caching, throttling, failover, or unified observability.

---

## 2. Observability / Tracing (Langfuse, Helicone, OpenTelemetry collectors)

### Already covered?
**PARTIAL** — OTel SDK is installed as a chromadb dependency but **no collector, no Langfuse/Helicone, no agent-instrumentation**.

### What exists
| Tool | Version | Location | Role |
|------|---------|----------|------|
| `opentelemetry-api` | 1.40.0 | `pip site-packages` | Core OTel API (spans, traces, metrics) |
| `opentelemetry-sdk` | 1.40.0 | `pip site-packages` | OTel SDK implementation |
| `opentelemetry-exporter-otlp-proto-grpc` | 1.40.0 | `pip site-packages` | OTLP gRPC exporter |
| `opentelemetry-exporter-otlp-proto-common` | 1.40.0 | `pip site-packages` | Shared OTLP proto encoder |
| `opentelemetry-proto` | 1.40.0 | `pip site-packages` | Protobuf definitions |
| `opentelemetry-semantic-conventions` | 0.61b0 | `pip site-packages` | Semantic conventions |

### Critical limitations
- All OTel libraries are **pulled in by chromadb as a dependency** — not intentionally installed for the agent harness
- **No OTel collector** is running (no `otelcol` binary, no Docker image)
- **No Langfuse** (not installed)
- **No Helicone** (not installed)
- **No LangSmith** (not installed)
- No agent-code instrumentation exists — Hermes/OMP don't emit spans

> **Result:** The OTel SDK is present but dormant. Standing up observability requires `pip install` + a collector binary — not from scratch but still work.

---

## 3. Memory / Knowledge Stores (vector DBs, pgvector, Mem0, Letta)

### Already covered?
**YES** — this is the strongest area. Multiple overlapping solutions exist.

### What exists
| Tool | Version | Location | Role |
|------|---------|----------|------|
| **ChromaDB** | 1.5.4 | `pip` | Vector DB (embeddings + search) |
| **Qdrant client** | 1.18.0 | `pip` | Vector DB client (Mem0 uses Qdrant backend) |
| **Mem0** | 2.0.4 | `pip` | Memory layer with Qdrant-backed persistent store at `~/.mem0/migrations_qdrant/` |
| **Neo4j** | 6.1.0 | `pip` | Graph database (knowledge graph support) |
| **Memlawb** | 0.1.0 | `Docker/memlawb/` | Zero-knowledge E2E-encrypted agent memory with MCP tools (`memory_save`, `memory_recall`, `memory_search`, etc.). Docker Compose at `~/Docker/memlawb/`, skinned with Fly.io deploy config |
| **Memlawb MCP skill** | — | `skills/memlawb-memory/SKILL.md` | Canonical recall-first/save-durable agent guidance |

### What's partially missing
- **pgvector**: Not installed (no PostgreSQL with pgvector extension detected)
- **Letta**: Not installed (not via pip or cargo)
- **Pinecone / Weaviate / Milvus**: Not installed

> **Result:** Rich memory stack already. Mem0 + Qdrant provides local vector memory. Memlawb provides E2E-encrypted cloud/self-hosted agent memory. No integration into the OMP/Hermes harness runtime exists — memory is tool-driven, not context-injected.

---

## 4. Policy Engines (OPA, Kyverno)

### Already covered?
**NO** — completely missing.

### What exists
- **Nothing.** No OPA binary, no Kyverno in K3s, no Rego policy files anywhere on the system.

### What's missing
- **OPA (Open Policy Agent)**: Not installed (no binary, no pip package, no Docker)
- **Kyverno**: No Helm chart, no manifests, no admission webhook
- **Custom policy engine**: No authz layer in Hermes/OMP configs

> **Result:** There is zero policy-as-code infrastructure. All tool access decisions are hard-coded in Hermes tool-allow lists. No runtime policy evaluation exists.

---

## 5. Evaluation Frameworks (deepeval, ragas, evaluate, etc.)

### Already covered?
**PARTIAL** — skill references exist, but no pip/cargo packages are installed.

### What exists
| Item | Location | Status |
|------|----------|--------|
| `evaluating-llms-harness` skill | `~/.hermes/skills/.bundled_manifest` | **Referenced but NOT installed** (directory absent) |
| `aeon-skill-evals` | `~/Github/bankrbot-skills/aeon-skill-evals/` | Third-party skill eval framework (assertion manifests, regression detection) |
| jcode `autojudge_enabled` | `~/Github/jcode/` | Agent feature flag for auto-judging |

### What's missing
- **deepeval**: Not installed via pip
- **ragas**: Not installed
- **evaluate** (HuggingFace): Not installed
- **langsmith**: Not installed
- **EleutherAI LM Eval Harness**: Not installed
- **No structured benchmarking pipeline** exists for the agent harness itself

> **Result:** Evaluation is the weakest area. No framework is installed. The Hermes eval skill is referenced but not downloaded. `aeon-skill-evals` exists in the Github repos but isn't set up. No CI/benchmark for agent output quality.

---

## 6. Hermes/OMP Plugin Coverage

### Already covered?
**NO** — existing plugins/skills don't fill gateway, observability, policy, or eval roles.

### Hermes plugins enabled
| Plugin | Role |
|--------|------|
| `herdr-agent-state` | Agent state sharing |
| `orca-status` | Orca IDE integration |

### Hermes platform toolsets
- `cli`, `telegram`, `discord`, `whatsapp`, `slack`, `signal`, `homeassistant`, `qqbot`, `teams`, `google_chat`
- All are **communication platform bridges** — none serve infrastructure roles

### OMP agent config
- Uses `opencode-go/glm-5.2` (default), `opencode-go/deepseek-v4-flash` (smol)
- No plugin system for gateway, observability, policy, or eval

> **Result:** Zero infrastructure plugins. All platform bandwidth is consumed by chat frontends. No slot for a gateway, tracer, policy engine, or evaluator exists in the plugin architecture.

---

## Summary Table

| # | Gap Area | Already Covered? | Key Assets Found | Quickest Gap to Fill |
|---|----------|-----------------|------------------|---------------------|
| 1 | Gateway/Proxy | **NO** | nginx (vanilla, no ML) | **LiteLLM** — `pip install litellm` gives model routing, failover, key management in one package. Minimal config change. |
| 2 | Observability/Tracing | **PARTIAL** | OTel SDK 1.40 (dormant, pulled by chromadb) | **Langfuse** — `pip install langfuse` + OTel collector setup. OTel SDK already installed reduces effort. |
| 3 | Memory/Knowledge | **YES** | ChromaDB, Qdrant, Mem0, Neo4j, Memlawb | Already well-covered. Focus: wire Memlawb MCP into harness for session-persistent memory. |
| 4 | Policy Engines | **NO** | None | **OPA** — single binary download, integrates via HTTP API. If lightweight need: Rego-less Python policy module. |
| 5 | Evaluation | **PARTIAL** | Skill refs exist, no packages | **deepeval** — `pip install deepeval` gives LLM-as-judge, metrics, CI integration. |
| 6 | Plugin Coverage | **NO** | Comms-only plugins | Requires architecture change to plugin system before any gap can be filled here. |

---

## Quickest Gap to Fill (Ranked)

1. **Memory integration** (already covered — wire Memlawb MCP into harness)
2. **LiteLLM gateway** (`pip install litellm`, configure proxy endpoint, update Hermes provider)
3. **Langfuse observability** (`pip install langfuse`, configure OTLP exporter, add tracing decorator to agent turns)
4. **deepeval eval** (`pip install deepeval`, define test cases for agent behaviors)
5. **OPA policy** (download binary, write Rego rules for tool-access policy)
6. **Plugin system architecture** (foundational — everything else depends on this)
