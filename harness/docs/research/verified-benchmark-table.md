# Verified Benchmark Table

**Last updated:** 2026-07-25
**Sources:** tbench.ai official leaderboards, LangChain blog, verified trace notes, arXiv 2605.23296, Reflexion paper 2303.11366 + production reports.

## 1. Terminal-Bench 2.0 — harness-only/verified entries

| Rank | Agent / Harness | Model | Snap | Accuracy | Notes |
|------|----------------|-------|------|----------|-------|
| 1 | Codex CLI | GPT-5.5 | 2026-04 | 82.0% | First-party harness + model |
| 2 | ForgeCode | GPT-5.4 | 2026-03-04 | 81.8% | Self-reported; later integrity review noted possible trace leakage risk; independent repro not fully verified |
| 3 | TongAgents | Gemini 3.1 Pro | 2026-03 | 80.2% | Official leaderboard verified run |
| 4 | ForgeCode | Claude Opus 4.6 | 2026-03-04 | 79.8% | Same caveat as rank 2 |
| 5 | SageAgent | GPT-5.3-Codex | 2026-03 | 78.4% | Verified |
| 6 | ForgeCode | Gemini 3.1 Pro | 2026-03-04 | 78.4% | Same caveat |
| 7 | Droid | GPT-5.3-Codex | 2026-02 | 77.3% | Verified |
| 11 | Meta-Harness | Claude Opus 4.6 | 2026-05-14 | 76.4% | Stanford IRIS / KRAFTON AI |
| 33 | Claude Code | Claude Opus 4.6 | 2026-02-07 | 58.0% | Verified; same model, weaker harness |

**Verified harness swing on same model:**
- Claude Opus 4.6: Claude Code 58.0% -> Terminus-KIRA 74.7% -> Meta-Harness 76.4%
- ForgeCode claims 81.8% for same/model classes, but integrity review tempers that finding.

## 2. LangChain harness engineering jump

| Agent | Model | Before | After | Delta | Harness-only change |
|------|-------|--------|-------|-------|--------------------|
| Deep Agents CLI | GPT-5.2-Codex | 52.8% | 66.5% | +13.7 pp | Yes |

## 3. Reflexion / reflection loop gains

| Pattern | Source | Domain | Baseline | +Reflection | Cost multiplier | Retrospective notes |
|--------|--------|--------|----------|------------|-----------------|--------------------|
| Reflexion | Shinn et al. 2023 | HumanEval PY | 80.1% | 91.0% | ~1.5x reported; production reports often 4-8x across episodes | Works with deterministic verifiers; reflection must be schema-constrained |
| Reflexion | Shinn et al. 2023 | HumanEval RS | 60.0% | 68.0% | similar | |
| Reflexion | Shinn et al. 2023 | MBPP PY | 80.1% | 77.1% | similar | Regression possible; one reported false-positive-sensitive case |
| Reflexion | Shinn et al. 2023 | HotPotQA EM | 34.0% | 51.0% | similar | Verbal RL is cross-episode, not intra-turn polish |
| Production Reflexion | Harbor Support case | deploy-checklist playbooks | 38% first-try | 71% first-try | ~1.9x token cost on failures | 44% less engineer intervention, false-success unchanged |
| Self-Reflection inference | arxiv 2510.20653 | math/sentiment/SQL/translation | varied | up to +220% relative gains on math for small models | prompt caching can cut reflection cost by up to 28% at 3 rounds |

**Ponytail takeaway:** Add one reflection pass only if you have a deterministic/semantic verifier and failure is expensive.

## 4. Parallel context compaction (arXiv:2605.23296)

| Backbone | Benchmark / setting | Baseline compaction | Parallel compaction | Improvement measured |
|---------|-------------------|--------------------|--------------------|----------------------|
| Llama-3.3-70B | HotpotQA 4k blocks | 8,582 tok | 8,360 tok | 2.13x throughput at matched decode volume |
| Llama-3.3-70B | HotpotQA 8k blocks | 8,582 tok | 6,823 tok | 1.70x throughput |
| Llama-3.1-8B | HotpotQA 4k blocks | 1,776 tok | 2,199 tok | 1.37x throughput |
| Llama-3.3-70B | LoCoMo style long dialogue | not shown | not shown | up to ~1.6x end-to-end wall-time improvement in quoted results |

**Operational note:** Compaction can dominate wall time at low token thresholds.
- gpt-oss-20B at 16k threshold: compaction up to 51.3% of end-to-end runtime.
- Block size is the first control knob; prompt tuning is secondary.

## 5. How to read this table in `gn`

- Prefer: terminal-bench/2.0 or 2.1 + official Harbor-based eval.
- Ignore single-number claims without CI/trace link.
- Treat benchmark expertise as transferable only after mapping: terminal env, tool surface, task taxonomy.
