# GN Harness ↔ 10-Layer Architecture Mapping

**Purpose:** Map `~/Github/nightforge/harness` onto `~/Documents/ai-lab-vault/10-Stack/10-layer-architecture-review-2026.md`.
Primary audience: `handbook.md`, future loop/prompt engineering decisions, and eval targets.

---

## Mapping summary

| vault 10-layer | harness concern | evidence in `handbook.md` / this repo |
|------|------|------|
| L1 Hardware/Infra | Local model serving truth | llama-server :8081, Qwen3-30B-A3B Q4_K_M, 39GB RAM, ~11.1 tok/s |
| L2 LLM Providers | Provider routing & cost truth | `handbook.md §2` token/runtime constraints |
| L3 Routing | Gateway / unified API proxy | `10-layer-architecture-review-2026.md §2` recommends LiteLLM/Helicone/Langfuse |
| L4 Failure Mining | Failure taxonomy + trace capture | `handbook.md §3` status: partial; `10-layer` gap C |
| L5 Proposal Engine | Post-failure improvement proposals | `10-layer`: implemented but static |
| L6 Validation Gate | Safety + preflight checks | `handbook.md §3`, §4 loop contract |
| L7 Versioning & Rollback | Prompt/config versioning, revert | `handbook.md §5` priority #1: versioned `prompts/` |
| L8 Routing Matrix | Model fallback / A-B routing | `10-layer`: should merge into L3 |
| L9 Benefit Measurement | Harness effectiveness metrics | `10-layer`: not designed; pending |
| L10 Weight Update | Closed-loop tuning | `10-layer`: not designed; pending |

---

## Where this repo addresses each layer

- **Prompt** → `src/presets.rs`; docs: `handbook.md §1`; target: `prompts/` externalized + cache-stable prefix.
- **Context** → token budget + head/tail tool truncation; scratchpad disk-backed; plan file.
- **Loop** → iteration cap, time cap, no-progress detection, escalation path.
- **Safety** → destructive-action gate; approval tiers; prefix/scope/write guards from vault Babysitter flow.
- **Observability** → trace + token + cost meter; first target: capture latency + completion tokens before adding more metrics.

---

## Research signals that should land here first

1. **Harness-only Terminal Bench 2.0 gains:** +13.7–24pp without model change.
2. **Reflexion:** +34% avg quality for +60% tokens on verifiable tasks; only if evaluator exists.
3. **Parallel compaction:** compaction dominates wall time; threshold + block size are knobs.

---

## Recommendations for this harness

- Add harness-level reflection pass only when completion is schema-verifiable.
- Add parallel compaction only if long-horizon sessions exceed 32K conversation tokens.
- Do A/B routing at gateway, not in presets.
