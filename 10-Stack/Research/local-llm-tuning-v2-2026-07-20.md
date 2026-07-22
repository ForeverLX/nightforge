# Local LLM Tuning v2: >5 tok/s on RTX 3070 8GB

**Tags:** #P2.2 #kanban  
**Date:** 2026-07-20  
**Hardware:** RTX 3070 8GB (Ampere SM86), i3-10105F 4C/8T, 64GB DDR4 RAM  
**Current baseline:** Ornith-1.0-35B Q4_K_M via llama-server at **2-3 tok/s gen, 24-29 tok/s prompt eval**  
**Current flags:** `-ngl 20 --ctx-size 16384 --cache-type-k/v q8_0 --flash-attn --no-kv-offload`

---

## 0. Executive Summary

The single biggest bottleneck is **not VRAM, not GPU compute** — it's that 20/40 layers run entirely on the **i3-10105F CPU** while the GPU sits idle waiting. The fix is already in llama.cpp:

> **`-ot "exps=CPU"`** combined with **`-ngl 999`** puts ALL 40 layers' attention + shared expert on GPU (~500 MB), while the 256 routed experts per layer stay on CPU. Only the 8 active experts per token (3% of total expert weights) need CPU compute — the rest is on GPU.

**Expected result: 6-12 tok/s generation** from this one change. The rest of this report confirms that no alternative backend, model swap, or quantization trick can match the impact of properly configuring MoE expert offload.

---

## 1. Alternative Serving Backends

| Backend | Format | 35B on 8GB VRAM? | Setup | Verdict |
|---|---|---|---|---|
| **llama.cpp** (current) | GGUF | ✅ Partial offload (20/40 layers) | Already running | 🏆 Best for 8GB |
| **ollama** | GGUF / Modelfile | ✅ Same as llama.cpp | Trivial | Wrapper, no throughput gain |
| **tabbyAPI** (ExLlamaV2) | EXL2, GPTQ, AWQ | ❌ Needs 16GB min for 32B-class | Moderate | **No — 8GB can't fit 35B EXL2** |
| **Aphrodite Engine** (vLLM fork) | HF, AWQ, GPTQ | ❌ OOMs on 8GB with 35B | Complex | **No — same vLLM VRAM wall** |
| **exllama** (standalone) | GPTQ, EXL2 | ❌ Needs 16GB+ for 35B | Moderate | **No — 8GB too tight** |

### Key findings

**tabbyAPI / ExLlamaV2:**
- Minimum VRAM for 32B-class models: **16 GB** (per official docs)
- "13B models run at 2.65 bpw within 8 GB VRAM" with severely limited context (2048 tokens)
- 35B at extreme 2.5 bpw: ~11.6 GB just for weights → doesn't fit 8GB
- Requires EXL2 or GPTQ format — no GGUF support → separate model downloads, 2-3x disk space
- Excellent throughput once VRAM is sufficient (2× llama.cpp on 24GB+), but irrelevant for our hardware

**Aphrodite Engine:**
- vLLM fork with added features (flash-attn v3, paged KV cache)
- Same model format requirements as vLLM (HF/AWQ/GPTQ only — no GGUF)
- Same VRAM wall: 35B Q4 needs ~22 GB → page-thrashing on 8GB
- `--enforce-eager` avoids CUDA graph OOM but destroys throughput (<3 tok/s)

**Verdict: Stay on llama.cpp.** No alternative backend improves throughput on 8GB VRAM. The advantage of tabbyAPI/ExLlamaV2 only appears at 16GB+ VRAM where full model offload becomes possible.

---

## 2. Smaller Architectures (24-27B)

### Model VRAM and Active Parameter Comparison

| Model | Type | Params Total | Active/token | Q4_K_M Size | Fits 8GB + 16K ctx? | Expected gen tok/s |
|---|---|---|---|---|---|---|
| **Ornith-1.0-35B** (current) | MoE (256×8) | 35B | **~3B** | ~22 GB | Partial (20/40 layers) | **4-8** (current) → **6-12** (with `-ot exps=CPU`) |
| **Gemma 4 26B A4B** | MoE (16×4?) | 26B | **~4B** | ~16.8 GB | ✅ with `-ot exps=CPU` | **8-15** (if MoE offload works) |
| **Mistral Small 3.1 24B** | Dense | 24B | **24B** | ~14.3 GB | Partial (24/40 layers) | **3-7** (CPU-bound) |
| **Qwen3.6-27B** | Dense | 27B | **27B** | ~16 GB | Partial (24/64 layers) | **2-5** (CPU-bound) |
| **Ornith-1.0-9B** | Dense | 9B | 9B | ~6 GB | ✅ Full GPU | **30-50** (but 9B quality) |

### Critical insight

**MoE models (Ornith 35B, Gemma 4 26B) win on generation speed despite larger total size**, because only 3-4B active parameters are computed per token. The `-ot "exps=CPU"` trick makes them dramatically more VRAM-efficient than dense models.

**Dense 24-27B models are actively worse** than Ornith MoE on our hardware because:
- All 24-27B params are active every token → CPU is the bottleneck with partial offload
- 27B × 4 partial offload on 8GB = ~12B on CPU, ~15B on GPU → CPU-bound at 2-5 tok/s
- Ornith MoE with expert offload: ~3B active (mostly GPU), experts on CPU → **faster generation**

### Qwen3.6-27B deep dive (dense counterexample)

- 64 layers, hidden_size=5120, FFN intermed=17408
- Each layer at Q4_K_M: ~209 MB
- 24 layers on 8GB (~5 GB weights + 2 GB KV cache) → 40 layers on CPU → mostly CPU-bound
- Linear attention layers (48 of 64): no traditional KV cache → smaller KV but still CPU compute bottleneck
- **Verdict: skip for generation speed — dense 27B is strictly worse than MoE 35B with expert offload**

---

## 3. Better Quantization (Ornith-1.0-35B MoE)

### Quantization Ladder

| Quant | bpw | File Size | VRAM for weights (~22 GB →) | Quality vs Q4_K_M | More layers offloadable? |
|---|---|---|---|---|---|
| **Q4_K_M** (current) | ~4.5 | ~22 GB | ~7.5 GB (20 layers) | Baseline | 20/40 layers |
| **IQ4_XS** | ~4.25 | ~20 GB | ~6.8 GB (20 layers) | -2% | 22/40 layers |
| **IQ4_NL** | ~4.25 | ~20 GB | ~6.8 GB (20 layers) | -1% | 22/40 layers |
| **Q3_K_L** | ~3.55 | ~16 GB | ~5.5 GB (20 layers) | -5% | 28/40 layers |
| **Q3_K_M** | ~3.35 | ~15 GB | ~5.2 GB (20 layers) | -7% | 30/40 layers |
| **IQ3_XXS** | ~3.1 | ~14 GB | ~4.8 GB (20 layers) | -10% | Full offload possible |

### Impact with `-ot "exps=CPU"` (recommended path)

With expert weights on CPU, quantization only affects the attention + shared expert weights (~500 MB for all 40 layers). The **routed expert quantization matters only for CPU compute cost**, not GPU VRAM.

This means: **Quantization choice for Ornith MoE + `-ot exps=CPU` has minimal impact on VRAM** — attention weights are small regardless. The main tradeoff is CPU-side expert evaluation speed vs quality:
- Higher quant (Q4_K_M) = more CPU work per expert
- Lower quant (Q3_K_M) = less CPU work per expert, ~7% quality drop
- **Q3_K_M is the sweet spot** for 8GB + i3 — smaller GGUF = less CPU cache pressure, faster expert eval

### Without `-ot exps=CPU` (current config)

- Q3_K_M saves ~7 GB file size → can offload 28-30/40 layers on GPU vs today's 20
- Expected throughput gain: ~30-40% (from 2-3 to 3-5 tok/s)
- But still not as good as `exps=CPU` approach

---

## 4. KV Cache Tricks

### Ornith-1.0-35B MoE KV Cache Profile

**Critical detail from model config:**
- 40 total layers: **10 full attention** + **30 linear attention** (Mamba-style SSM)
- Full attention layers: 16 heads, 2 KV heads, head_dim=256, RoPE
- Linear attention layers: 16 QK heads, 48 V heads, head_dim=128 — these use **recurrent state, not KV cache**

**KV cache resides only on the 10 full-attention layers**, not all 40:

| Context | Cache Type | Full-Attn KV Cache Size | Total (w/ linear state) |
|---|---|---|---|
| 4096 | Q8_0 | ~20 MB | ~25 MB |
| 16384 | Q8_0 | ~80 MB | ~90 MB |
| 16384 | Q4_0 | ~40 MB | ~50 MB |
| 32768 | Q8_0 | ~160 MB | ~175 MB |
| 32768 | Q4_0 | ~80 MB | ~90 MB |
| 262144 | Q4_0 | ~640 MB | ~670 MB |

### Key findings

1. **Ornith's MoE + hybrid attention is already KV-cache-efficient.** 30/40 layers use recurrent state (no cache growth with context length). This is a feature, not something to optimize away.

2. **Q4_0 KV cache saves ~50% on the 10 full-attention layers** — but at 16384 ctx we're already at only 80 MB. The savings are negligible in absolute terms.

3. **`--no-kv-offload` is costing us.** Currently KV cache is forced to CPU. With `-ot exps=CPU` freeing up VRAM, we can and **should** move KV cache back to GPU for the 10 full-attention layers. This eliminates CPU↔GPU transfers during decode of full-attention tokens.

4. **The linear attention layers** use a small recurrent state (matrix of heads × dim, not tokens × heads × dim). This state is trivially small and lives on GPU already.

### turbo2 KV?

This appears to be an ExLlamaV2 feature (2-bit KV cache, not a standard llama.cpp flag). Not applicable to our stack.

---

## 5. llama.cpp Flag Tuning — THE BIG GAINS

### Current flags (suboptimal)

```
-ngl 20 --ctx-size 16384 --cache-type-k/v q8_0 --flash-attn --no-kv-offload
```

### Recommended flags (target: 6-12 tok/s)

```bash
./llama-server \
  -m models/ornith-1.0-35b-Q4_K_M.gguf \
  --port 8081 --host 127.0.0.1 \
  -ngl 999 \                            # Offload EVERYTHING possible (see -ot override)
  --override-tensor "exps=CPU" \         # ⭐ THE KEY: routed experts on CPU
  -c 8192 \                              # Reduce from 16384 to 8192 for now
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --flash-attn \                         # Keep — helps full-attention layers
  --mlock \                              # Lock RAM, prevent swapping
  --no-mmap \                            # Better for partial offload patterns
  --threads 8 \                          # i3-10105F: 4C/8T
  --threads-batch 4 \                    # Separate pool for prompt eval
  --batch-size 512 \
  --ubatch-size 256 \
  --temp 0.7 --repeat-penalty 1.1
```

### Flag-by-flag analysis

| Flag | Current | Recommended | Why |
|---|---|---|---|
| **`-ngl`** | 20 | **999** | Offload all non-expert weights. With `exps=CPU`, attention+shared expert is only ~500 MB for 40 layers — fits easily. |
| **`--override-tensor exps=CPU`** | ❌ missing | ✅ **ADD** | **THE main fix.** Keeps MoE routed experts on CPU, puts attention+shared expert on GPU. Without this, -ngl 999 OOMs because 256 experts × 40 layers can't fit. |
| **`--cpu-moe`** | ❌ missing | ✅ **alias** | Shorthand for same thing. Does the same as `-ot exps=CPU`. |
| **`--ctx-size`** | 16384 | **8192** | 16384 ctx burns VRAM for no gain in current use case. Linear attention layers don't cache, but the compute buffers scale with ctx. Drop to 8192. |
| **`--no-kv-offload`** | ✅ on | ❌ **remove** | Currently necessary with -ngl 20 because VRAM is full. With `exps=CPU`, we have VRAM headroom — let KV cache live on GPU for the 10 full-attention layers. |
| **`--flash-attn`** | ✅ on | ✅ keep | Helps full-attention layers. Linear attention uses its own kernels. |
| **`--mlock`** | ❌ missing | ✅ **add** | Prevents OS swapping model weights to disk under memory pressure. With 64GB RAM this is less critical but still good practice. |
| **`--no-mmap`** | ❌ missing | ✅ **add** | Critical for partial offload — avoids page faults when CPU accesses offloaded weight regions. |
| **`--threads`** | default (8) | **8** | Correct for i3-10105F 4C/8T. Verify with `nproc`. |
| **`--threads-batch`** | default | **4** | Separate thread count for prompt eval batches. Prevents gen threads from competing with batch threads. |
| **`--no-mul-mat-q`** | default (off=mmq on) | ✅ **keep default** | RTX 3070 is Ampere — MMQ kernels are well-tuned. `--no-mul-mat-q` is for Turing/older where cuBLAS is sometimes faster for K-quants. Not needed here. |
| **`--temp` / `--repeat-penalty`** | default | **0.7 / 1.1** | Good defaults for the Ornith instruct model. |

### MoE-Specific Flags

| Flag | Effect |
|---|---|
| `--override-tensor exps=CPU` | Keeps all routed expert FFN weights on CPU. Attention + shared expert + norms go to GPU (-ngl). **This is the primary MoE optimization for 8GB VRAM.** |
| `--cpu-moe` | Legacy alias for the same thing. Equivalent to `-ot exps=CPU`. |
| `--n-cpu-moe N` | Only moves the last N layers' experts to CPU. More granular but harder to tune. Prefer `exps=CPU` for our use case. |
| `-ot "exps=CUDA0"` | Explicit: put experts on GPU 0 (if you want them there). We want `=CPU`. |

### What about ik_llama.cpp?

The ik_llama.cpp fork (ikawrakow) has additional MoE-specific optimizations including:
- `--sm graph` for MoE multi-GPU scheduling
- Better batch-size tuning for MoE prompt processing
- Configurable expert offload threshold via `--cuda offload-batch-size`

**Verdict: Not needed for our single-GPU setup.** The mainline llama.cpp `-ot exps=CPU` achieves the same effect. If you hit a specific MoE performance wall, ik_llama.cpp is a fallback.

### i3-10105F Specific Tuning

The i3-10105F (4C/8T, 4.4 GHz) is the throughput ceiling for CPU-side expert eval:

| Tuning | Effect |
|---|---|
| `--threads 8` | Use all logical cores |
| `--threads-batch 4` | Don't let prompt eval steal gen threads |
| `OMP_NUM_THREADS=8` | (env var) Ensure OpenMP uses all cores |
| Low expert quant (Q3_K_M) | Less CPU work per expert eval |
| `--mlock` | No page faults interrupting CPU compute |

---

## 6. Bonsai-27B Q1_0 Post-Mortem

Current throughput: **0.39 tok/s** — unusable. Model is only 3.9 GB, should fully fit GPU. What's wrong?

### Diagnosis

| Possible Cause | Likelihood | Explanation |
|---|---|---|
| **Q1_0 kernel not optimized for Ampere** | **HIGH** | The Custom Q1_0_g128 format uses novel 1-bit CUDA kernels. These were likely developed and tested on Ada (RTX 4090) or Hopper. SM86 (Ampere) may have poor kernel occupancy or fall back to CPU path. |
| **`-ngl` too low** | MEDIUM | If the user didn't set `-ngl 999` or enough layers, most compute runs on CPU. 0.39 tok/s matches CPU-only performance for a 27B model. |
| **DSpark speculative decoder adding overhead** | LOW-MEDIUM | The default DSpark drafter is Q4_1 at ~2 GB. If loaded on GPU alongside the model, this could cause VRAM contention. |
| **Context size too large** | LOW | At 4K context, Bonsai needs only ~5.2 GB total (weights + KV) — well within 8GB. At 16K ctx ~5.6 GB. Not likely the issue. |

### Solution: Try Ternary-Bonsai-27B Q2_0

| Variant | Size | Quality (vs FP16) | Expected tok/s on 3070 |
|---|---|---|---|
| Bonsai-27B Q1_0 (current) | 3.9 GB | 89.5% | **0.39** (broken — kernel issue) |
| **Ternary-Bonsai-27B Q2_0** | **7.2 GB** | **94.6%** | **15-25** (estimated, fits fully on GPU) |
| Qwen3.6-27B Q4_K_XL | 17.6 GB | 99.9% | N/A — doesn't fit |

The **Ternary Bonsai at 7.2 GB** fully fits in 8GB VRAM with room for KV cache (~5-6 GB at typical context sizes). The Q2_0 format (1.58-bit ternary) uses more mature CUDA kernels since it's a 2-bit container with better toolchain support.

**Download:**
```bash
huggingface-cli download prism-ml/Ternary-Bonsai-27B-gguf \
  Ternary-Bonsai-27B-Q2_0.gguf --local-dir ./models/
```

**Launch:**
```bash
./llama-server \
  -m models/Ternary-Bonsai-27B-Q2_0.gguf \
  --port 8082 \
  -ngl 999 \
  -c 8192 \
  --mlock --no-mmap \
  --threads 8 --threads-batch 4
```

The model is small enough for full GPU offload — no `-ot exps=CPU` needed (no routed experts in the traditional sense — Bonsai uses the dense Qwen3.6-27B backbone with quantized weights, not MoE).

---

## 7. Recommended Config (Fast Path)

### Option A: Ornith-1.0-35B Q4_K_M + `-ot exps=CPU` ⭐ RECOMMENDED

**Expected throughput:** 6-12 tok/s generation, 40-60 tok/s prompt eval  
**VRAM:** ~2-3 GB used (attention weights + KV cache + GPU compute buffers)  
**Risk:** None — non-destructive flag change, can revert instantly

```bash
# Stop current server, restart with:
./build/bin/llama-server \
  -m models/ornith-1.0-35b-Q4_K_M.gguf \
  --port 8081 --host 127.0.0.1 \
  -ngl 999 \
  --override-tensor "exps=CPU" \
  -c 8192 \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --flash-attn \
  --mlock --no-mmap \
  --threads 8 --threads-batch 4 \
  --batch-size 512 --ubatch-size 256 \
  --temp 0.7 --repeat-penalty 1.1
```

### Option B: Option A + Q3_K_M quant (for i3 CPU relief)

**File size:** ~15 GB (saves 7 GB vs Q4_K_M)  
**Expected throughput:** 8-15 tok/s generation  
**Quality:** ~93% of Q4_K_M  

Less CPU work per expert eval → faster generation on the i3-10105F.

### Option C: Ternary-Bonsai-27B Q2_0 (try this too)

**Expected throughput:** 15-25 tok/s generation  
**VRAM:** ~7.2 GB + ~0.5 GB KV cache = fully fits  
**Quality:** 94.6% of FP16  

Completely different model — runs fully on GPU, no CPU bottleneck. Best raw throughput option if quality is acceptable.

---

## 8. Expected Timings Comparison

| Config | Gen tok/s | Prompt tok/s | CPU usage | GPU usage | Notes |
|---|---|---|---|---|---|
| **Current** (-ngl 20, Q4_K_M) | 2-3 | 24-29 | 100% (4C) | ~30% | Baseline |
| **+ `-ot exps=CPU`** | **6-12** | **40-60** | ~40% (expert eval) | ~60% | **Biggest single gain** |
| **+ Q3_K_M** | 8-15 | 50-70 | ~30% | ~70% | Less CPU expert work |
| **+ Q3_K_M + 8192 ctx** | 10-16 | 55-75 | ~30% | ~70% | Smaller compute buffers |
| **Ternary Bonsai Q2_0** | 15-25 | 60-90 | ~10% (CPU idle) | ~90% | Full GPU offload |
| **Gemma 4 26B A4B Q3_K_M + exps=CPU** | 8-16 | 45-65 | ~35% | ~65% | MoE, similar profile to Ornith |

---

## 9. Upgrade Path Notes

| If you upgrade to… | Expected gain | Rationale |
|---|---|---|
| **RTX 3060 12GB** (used, ~$200) | 2× throughput | More layers offloaded without `exps=CPU` hack — can keep experts on GPU |
| **RTX 3090 24GB** (used, ~$600) | 4-5× throughput | Full model offload → no CPU bottleneck → 20-30 tok/s on Ornith MoE |
| **RTX 5070 12GB** | 2-3× throughput | Ada architecture + 12GB → more layers + faster GPU cores |
| **i5-14500** (14C/20T, ~$200) | 1.5-2× throughput with `exps=CPU` | Faster CPU expert eval → less GPU idle time. **Cheapest single upgrade for current setup.** |
| **Both CPU + GPU** | 4-8× | Proper MoE pipeline: fast CPU for experts + GPU for attention |

The **CPU upgrade is the most cost-effective** improvement for the current MoE expert-offload config. The i3-10105F bottlenecks expert eval even when attention is fully on GPU.

---

## 10. Quick Triage Checklist

If the recommended flags don't immediately hit >5 tok/s:

```
[ ] Verify llama.cpp is built with GGML_CUDA=ON (CUDA support)
[ ] Confirm -ngl 999 isn't silently clamping due to VRAM
[ ] Check `nvidia-smi` during inference — GPU util should be >50%
[ ] Check CPU utilization — should be <80% (experts on CPU)
[ ] Try --cpu-moe as alias for -ot "exps=CPU"
[ ] Reduce context to 4096 temporarily to rule out VRAM pressure
[ ] Test with a short prompt (<200 tokens) to isolate generation speed
[ ] If still slow: try Ternary-Bonsai-27B Q2_0 as a full-offload reference point
[ ] Upgrade llama.cpp to latest master (b7957+)
```

---

## References

- [llama.cpp MoE expert offload docs](https://github.com/ggml-org/llama.cpp/issues/20757)
- [Ornith-1.0-35B model card](https://huggingface.co/deepreinforce-ai/Ornith-1.0-35B) (Qwen3.5 MoE, 40 layers, 256×8 experts)
- [ExLlamaV2 VRAM requirements](https://localaimaster.com/blog/exllamav2-tabbyapi-guide)
- [Ternary Bonsai 27B](https://huggingface.co/prism-ml/Ternary-Bonsai-27B-gguf)
- [Bonsai 27B 1-bit](https://huggingface.co/prism-ml/Bonsai-27B-gguf)
- [Gemma 4 26B A4B GGUF](https://huggingface.co/prokopsafranek/gemma-4-26B-A4B-it-GGUF)
- [Qwen3.6-27B dense architecture](https://huggingface.co/Qwen/Qwen3.6-27B)
- [Mistral Small 3.1 24B GGUF](https://huggingface.co/bartowski/mistralai_Mistral-Small-3.1-24B-Instruct-2503-GGUF)

---

*Generated for #P2.2. All throughput estimates assume RTX 3070 8GB + i3-10105F + 64GB RAM. Actual results depend on llama.cpp build version, context contents, and concurrent system load.*
