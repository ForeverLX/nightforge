---
type: research-report
status: complete
scope: local-llm
models: [ornith-1.0-35b, qwen3.5-35b-a3b, qwen3.6-35b-a3b, qwen3.5-9b, ornith-1.0-9b, deepseek-r1-distill-8b]
tags: [local-llm, llama.cpp, vllm, ornith, moe, ncmoe, rtx-3070, 8gb-vram]
priority: P0
confidence: high
impact: high
version: 1.0
created: 2026-07-18
updated: 2026-07-18
source: S140-deep-research
related: [10-Stack/10-layer-harness-build.md, 40-Memory/azrael-decisions.md]
---

# Local LLM Config Research — RTX 3070 8GB (S140)

**Date:** 2026-07-18
**Researcher:** Hermes (CR1MS0N profile)
**Trigger:** User asked for deep research on local model options for our hardware + best config tweaks
**Output:** Recommended llama-server config that takes current 2-3 t/s → 30-40 t/s (10-15x speedup)

## Executive Summary

Three findings dominate everything else:

1. **The current `llama-server` config is missing the single most impactful flag for MoE models on 8GB cards: `--n-cpu-moe`.** Adding it gets 4.7x speedup on a 3070 Ti 8GB per published benchmarks. Same architecture family as our Ornith-1.0-35B.
2. **Ornith-1.0-35B is a 256-expert MoE post-trained on Qwen 3.5 MoE base**, identical architecture to the Qwen3.5-35B-A3B that those benchmarks cover. Findings transfer directly.
3. **The hard ceiling on 8GB VRAM is `7B-9B dense OR ~35B MoE with MoE-aware offload`.** For coding/agentic work, Ornith-1.0-35B MoE is the right choice. For general speed, Qwen3.5-9B dense is the right choice.

## Hardware Profile (verified S140)

- GPU: NVIDIA GeForce RTX 3070 (Ampere, sm_86)
- VRAM: 8 GB GDDR6
- Bandwidth: 448 GB/s
- CUDA cores: 5,888
- TDP: 220W
- Display connected: yes (544 MiB baseline reserve)
- ~7.5 GB available for inference workloads

## Current Model: Ornith-1.0-35B (verified architecture)

| Field | Value |
|-------|-------|
| Architecture | qwen3_5_moe (Qwen 3.5 MoE base, post-trained for agentic coding) |
| Total params | 35B |
| Active params/token | ~3B (8 of 256 experts fire per token) |
| Hidden layers | 40 |
| Experts | 256 total, 8 active per token |
| Attention | Gated Delta Net hybrid (linear + full attention) |
| Context | 256K native (reduced to 65K in our config) |
| Quantization | Q4_K_M (20 GB file) |
| Vision encoder | Included but unused for text-only work |
| License | MIT, no regional restrictions |

**Same architecture family as:** Qwen3.5-35B-A3B and Qwen3.6-35B-A3B. Benchmark data from those models applies directly to Ornith.

## Current Config (broken)

File: `~/.config/systemd/user/llama-server.service`

```
--model /home/ForeverLX/Tools/ai/local-models/ornith-1.0-35b-Q4_K_M.gguf
--host 127.0.0.1 --port 8081
--ctx-size 65536
--n-gpu-layers 10
--flash-attn on
--no-kv-offload
--chat-template chatml
--parallel 1
```

**Problems:**
1. `--n-gpu-layers 10` = 10/40 = only 25% of layers on GPU. Rest on CPU. PCIe bottleneck → catastrophic slowdown (per inferencerig guide: "1.8 t/s" when layers spill to system RAM).
2. **No `--n-cpu-moe` flag** → llama.cpp default MoE offload behavior on 8GB = catastrophic (Qwen3.5-35B-A3B at 8.7 t/s baseline per Medium benchmark).
3. `--ctx-size 65536` with `--no-kv-offload` and fp16 KV cache = eats 2-3 GB of VRAM for KV cache, leaving even less for weights.
4. KV cache is fp16 (no `--cache-type-k/v` quantization) — wastes VRAM.

**Measured performance with this config:**
- User workload: 18.26 t/s prompt-eval, 2-3 t/s generation
- S140 curl test: 0.03 t/s on 10-token completion (cold start, single-call metric)
- Verdict: 2-3 t/s is the real generation rate, 10-15x below what the model can do

## Recommended Config (the answer)

File: `~/.config/systemd/user/llama-server.service`

```
[Service]
ExecStart=/home/ForeverLX/.local/bin/llama-server \
  --model /home/ForeverLX/Tools/ai/local-models/ornith-1.0-35b-Q4_K_M.gguf \
  --host 127.0.0.1 --port 8081 \
  --ctx-size 16384 \
  --n-gpu-layers 99 \
  --flash-attn on \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --n-cpu-moe 25 \
  --chat-template chatml \
  --parallel 1
Restart=on-failure
RestartSec=10
```

### What each flag does

| Flag | Old | New | Why |
|------|-----|-----|-----|
| `--n-gpu-layers` | 10 | 99 | Offload all possible layers to GPU. With `-ncmoe` controlling expert placement, no risk of OOM. |
| `--n-cpu-moe` | (unset) | 25 | Keep 25 expert blocks on CPU. Per Medium benchmark, sweet spot for 8GB = 25 (40.9 t/s on 3070 Ti with Qwen3.5-35B-A3B Q4_K_M). |
| `--ctx-size` | 65536 | 16384 | 16K is plenty for OMP/LDR queries. Saves 1-2 GB KV cache VRAM at 16K vs 65K. |
| `--cache-type-k` | (fp16) | q8_0 | Quantize K cache to 8-bit. Halves KV cache VRAM. Tiny quality loss. |
| `--cache-type-v` | (fp16) | q8_0 | Same for V cache. |
| `--no-kv-offload` | on | (removed) | Let KV cache spill to RAM at long contexts instead of failing. |
| `--parallel` | 1 | 1 | Already correct. Default `n_parallel=auto` causes 10x slowdown for 35B-A3B per YashwanthMY15/Qwen-3.5-16G-Vram-Local discovery. |

### Expected performance

Per Medium benchmark on RTX 3070 Ti (slightly faster than our 3070 due to GDDR6X bandwidth):

| Metric | Current | After fix | Improvement |
|--------|---------|-----------|-------------|
| Generation tok/s | 2-3 | **30-40** | 10-15x |
| Prompt-eval tok/s | 18.26 | 100-150 (estimated) | 5-8x |
| VRAM used | 7.5 GB | 6.9-7.5 GB | Same or less |
| Context | 65K | 16K (configurable) | Sacrificed |

### Tuning procedure after applying

1. Restart service: `systemctl --user daemon-reload && systemctl --user restart llama-server`
2. Re-measure: `time curl -s -X POST http://127.0.0.1:8081/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"/home/ForeverLX/Tools/ai/local-models/ornith-1.0-35b-Q4_K_M.gguf","messages":[{"role":"user","content":"Write a fibonacci function in Python"}],"max_tokens":200,"temperature":0.6}'`
3. If tok/s is below 25, sweep `-ncmoe` from 19 to 30 in steps of 2, monitor with `nvidia-smi`, pick the value that gives highest tok/s while keeping VRAM < 7.5 GB
4. If above 35, leave at 25 (don't push further — diminishing returns and stability risk)

## Alternative Models Worth Considering

| Model | Params | Active | Quant | VRAM | Tok/s on 8GB | Quality Tier | Notes |
|-------|--------|--------|-------|------|--------------|--------------|-------|
| **Ornith-1.0-35B (current)** | 35B MoE | ~3B | Q4_K_M | 20 GB | 2-3 → 30-40 | Strong coding (SOTA agentic) | Recommended for code/agentic work |
| Qwen3.5-35B-A3B | 35B MoE | ~3B | Q4_K_M | 20.5 GB | 27-43 with ncmoe | General + coding | Same arch; broader benchmarks |
| Qwen3.6-35B-A3B | 35B MoE | ~3B | UD-Q4_K_XL | 22 GB | 22-30 (slower) | Best in tier | Hybrid attention; slower but more capable |
| Qwen3.5-9B | 9B Dense | 9B | Q4_K_M | 6.0 GB | 54-58 | Top sub-10B | Fits fully; faster, less capable |
| Ornith-1.0-9B | 9B Dense | 9B | Q4_K_M | 6.0 GB | ~55 | Strong coding | 9B dense variant of Ornith |
| DeepSeek R1 Distill 8B | 8B Dense | 8B | Q4_K_M | 5.8 GB | 50-60 | Best reasoning | Reasoning specialist |

### Recommendation by use case

- **Coding / agentic work (primary):** Keep Ornith-1.0-35B with the recommended config
- **General chat / fast responses:** Qwen3.5-9B (54 t/s, top sub-10B quality)
- **Reasoning-heavy:** DeepSeek R1 Distill 8B
- **Quality ceiling:** Qwen3.6-35B-A3B at UD-Q4_K_XL (slower but most capable)

## Engine Comparison (research finding)

For our single-user, RTX 3070 use case, the engine choice is clear:

| Engine | Best For | Our Fit | Notes |
|--------|----------|---------|-------|
| **llama.cpp** | Single-user, CPU fallback, GGUF | **Best fit** | Already deployed; `--ncmoe` unlocks 4.7x |
| Ollama | Local dev, simplicity | Same as llama.cpp | Wraps llama.cpp; 10-30% slower; fewer knobs (no ncmoe early) |
| vLLM | Production multi-user serving | **Wrong** | Needs 16+ GB VRAM; over-engineered for single user; no CPU offload |
| ExLlamaV2 | Max single-user speed on big GPU | **Marginal** | EXL2 format; 32% faster than llama.cpp on 4090 but no benefit at 8GB; Linux/Python only |

**Verdict:** Stay on llama.cpp. The `--ncmoe` flag discovery is llama.cpp's win — Ollama doesn't expose it as cleanly, and vLLM is for production serving we don't need.

## Quantization Notes

Q4_K_M is the right default. Brief guide for our setup:

| Quant | VRAM for 35B | Quality | When to use |
|-------|--------------|---------|-------------|
| Q3_K_M | ~14 GB | Visible degradation | If we want to fit in 8GB without ncmoe tricks |
| **Q4_K_M** | **~20 GB** | **Default; recommended** | **Current. Sweet spot.** |
| Q5_K_M | ~25 GB | Marginal gain | Need more offload; not worth speed cost on 8GB |
| Q6_K | ~28 GB | Near-fp16 | Doesn't fit even with ncmoe |
| Q8_0 | ~36 GB | Reference | Doesn't fit |

For 8GB cards, Q4_K_M is the answer. Don't waste time on Q5/Q6.

KV cache quantization (Q8_0) saves ~30-50% VRAM with negligible quality loss — already in the recommended config.

## Sources

- inferencerig.com — RTX 3070/3070 Ti 8GB LLM Guide 2026 Benchmarks
- specpicks.com — Per-Model GPU Requirements 2026, Per-Model Hardware Picker
- llmrun.dev — Best AI Models for RTX 3070 (8GB)
- nestfrontier.com — 3070 35B Model 22 t/s
- dev.to/pat9000 — llama.cpp n-gpu-layers VRAM Guide 2026
- dev.to/kenimo49 — RTX 4070 + Qwen 35B 2.8x speedup with `--cpu-moe`
- medium.com (kenimo49) — One Flag Tripled My Tokens Per Second on an 8GB GPU (the `-ncmoe` 4.7x finding)
- localllm.in — llama.cpp VRAM Requirements Complete 2026 Guide
- craftrigs.com — Q5_K vs Q4_K_M Quantization Guide 2026
- craftrigs.com — ExLlamaV2 vs llama.cpp vs vLLM Comparison
- bswen.com — llama.cpp vs vLLM Speed
- techplained.com — Ollama vs vLLM vs llama.cpp 132 tok/s Benchmarks
- github.com/YashwanthMY15/Qwen-3.5-16G-Vram-Local — Qwen 3.5 context cliff + parallel discovery
- developers.redhat.com — llama.cpp vs vLLM Choosing the Right Engine
- github.com/ggml-org/llama.cpp/releases — b9911 changelog (Q5_K GPU paths, Qwen3.5/3.6 optimizations)
- ornith.site — Ornith 1.0 model family overview
- github.com/deepreinforce-ai/Ornith-1 — Ornith 1.0 architecture docs
- huggingface.co/deepreinforce-ai/Ornith-1.0-35B — model config.json (qwen3_5_moe, 256 experts, 40 layers)

## Action Items

### P0 — Operator decision required (apply the recommended config)
1. Edit `~/.config/systemd/user/llama-server.service` to the recommended config
2. `systemctl --user daemon-reload && systemctl --user restart llama-server`
3. Re-measure with the curl test above
4. If tok/s < 25, sweep `-ncmoe` 19-30 in steps of 2
5. Update S140.8 addendum with measured result

### P1 — Next session
1. Install LDR in uv venv, wire to llama.cpp via `custom_openai_endpoint`
2. Run a real research query with LDR, time it, document quality
3. If 1-3 min/query is acceptable, integrate as L3.5/L4 helper

### P2 — Backlog
1. Add Qwen3.5-9B as a second llama-server instance (port 8082) for fast tier if LDR work shows value
2. Investigate speculative decoding (Qwen3-8B + 1.7B draft combo hit 280 t/s on 24GB)
3. Continue 10-layer L6 Validation Gate design in parallel

## Verification

After applying the recommended config, verify with:

```bash
# 1. Service is running with new flags
systemctl --user show llama-server | grep -E "(ExecStart|n-gpu|n-cpu)"
# Should show: -ngl 99 -ncmoe 25 --cache-type-k q8_0 --cache-type-v q8_0 --ctx-size 16384

# 2. Model loads successfully
curl -s http://127.0.0.1:8081/v1/models | head -3
# Should return the ornith model metadata

# 3. Generation speed
time curl -s -X POST http://127.0.0.1:8081/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"/home/ForeverLX/Tools/ai/local-models/ornith-1.0-35b-Q4_K_M.gguf","messages":[{"role":"user","content":"Write a Python function to compute fibonacci"}],"max_tokens":200,"temperature":0.6}' | python -c "import json,sys; r=json.load(sys.stdin); print('Generated:', r['usage']['completion_tokens'], 'tokens'); print('Eval rate:', r['usage']['completion_tokens']/0.0, '(see timings')"
# Expect 200 tokens in ~5-7 seconds (30-40 t/s)

# 4. VRAM usage
nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits
# Expect 6900-7500 MB during inference
```

Ponytail: this is the deliverable. Apply the systemd change, re-measure, report back. Don't iterate further on research until we know the actual realized speed.
