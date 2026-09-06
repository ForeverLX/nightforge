# NightForge Local Model Documentation

> Single source of truth for all local model configurations, server builds, and launch procedures.
> Document changes here before modifying any model config. Track advantages/disadvantages.

## Model Summary

| Model | Architecture | Size (Q4_K_M) | Context | Purpose | Port |
|-------|-------------|---------------|---------|---------|------|
| Spark-X2.5-4B | spark2_5 (hybrid attention, reasoning) | 2.6 GB | 32K | Code generation, architecture | 8080 |
| Ornith-1.0-9B | Dense (Qwen 3.5 base, self-scaffolding) | 5.3 GB | 32K | Code review, multi-file refactoring | 8080 |
| LFM2.5-2.6B | lfm2 (dense, fast) | 1.67 GB | 32K | Quick edits, embeddings, companion | 8081 |
| LFM2.5-8B-A1B | lfm2moe (MoE, 1.5B active) | 5.16 GB | 32K | MoE general purpose | 8080 |
| Qwen2.5-Coder-7B | Dense (baseline only) | 4.4 GB | 32K | Baseline comparison | 8080 |

All models stored at: `~/Downloads/Local-Models/`

## Server Build Requirements

### Spark-X2.5-4B — CUSTOM BUILD REQUIRED

The system `/usr/bin/llama-server` (llama.cpp-cuda package) does NOT support the `spark2_5` architecture. You MUST use the custom build:

```
Build source: github.com/XHToken/llama.cpp (upstream PR #27868 pending)
Build location: ~/Downloads/Local-Models/llama.cpp-spark/
Build command: cmake -B build -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release
Binaries: ~/Downloads/Local-Models/llama.cpp-spark/build/bin/{llama-server,llama-cli,llama-bench}
```

**Custom build uses shared library architecture** — the binaries are thin 16KB executables that link against `.so` files in the same directory. You MUST set `LD_LIBRARY_PATH` when running.

### All Other Models — SYSTEM BUILD

Ornith, LFM2.5-2.6B, LFM2.5-8B-A1B, Qwen2.5-Coder-7B use the system `/usr/bin/llama-server` (llama.cpp-cuda package, version b10753).

## Server Launch Commands

### Spark-X2.5-4B (port 8080)

```bash
# REQUIRED: Use custom Spark build with LD_LIBRARY_PATH
LD_LIBRARY_PATH=~/Downloads/Local-Models/llama.cpp-spark/build/bin \
  ~/Downloads/Local-Models/llama.cpp-spark/build/bin/llama-server \
  --model ~/Downloads/Local-Models/Spark-X2.5-4B-Q4_K_M.gguf \
  --port 8080 --threads 8 --host 127.0.0.1 --embedding
```

### Ornith-1.0-9B (port 8080 — same port, different model)

```bash
# Use system llama-server
llama-server \
  --model ~/Downloads/Local-Models/Ornith-1.0-9B-Q4_K_M.gguf \
  --port 8080 --threads 8 --host 127.0.0.1 --embedding
```

### LFM2.5-2.6B (port 8081 — separate port for embeddings)

```bash
# CRITICAL: --pooling mean is REQUIRED for LFM embeddings
# Default pooling is 'none' which is OpenAI-incompatible
llama-server \
  --model ~/Downloads/Local-Models/LFM2.5-2.6B-Q4_K_M.gguf \
  --port 8081 --threads 4 --host 127.0.0.1 --embedding --pooling mean
```

### LFM2.5-8B-A1B (port 8080)

```bash
llama-server \
  --model ~/Downloads/Local-Models/LFM2.5-8B-A1B-Q4_K_M.gguf \
  --port 8080 --threads 8 --host 127.0.0.1 --embedding
```

### Qwen2.5-Coder-7B (port 8080)

```bash
llama-server \
  --model ~/Downloads/Local-Models/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf \
  --port 8080 --threads 8 --host 127.0.0.1 --embedding
```

## Critical Constraint: ONE MODEL AT A TIME

**Two llama-server instances CANNOT run simultaneously.** They conflict on:
- Port (only one model per port)
- GPU memory (CUDA VRAM is limited — RTX 3070 has 8GB)
- CPU threads

**Workflow for switching models:**
1. Kill current server: `kill <PID>` or `kill_shell({taskId: "..."}))`
2. Wait 2-3 seconds for port release
3. Start new server with different model/port
4. Verify with `curl -s http://127.0.0.1:<port>/v1/models`

**Exception:** LFM2.5-2.6B can run on port 8081 while Spark runs on 8081 IF you have enough VRAM. In practice on RTX 3070, only one model should be loaded at a time.

## Throughput Benchmarks (RTX 3070, llama.cpp-cuda b10753)

| Model | Prompt (t/s) | Generate (t/s) | VRAM (32K ctx) |
|-------|-------------|----------------|----------------|
| LFM2.5-2.6B | 7,457 | 189 | ~2 GB |
| Spark-X2.5-4B | 389 | 90 | ~4.5 GB |
| Qwen2.5-Coder-7B | 3,346 | 82 | ~6 GB |
| Qwen3-8B | 3,085 | 76 | ~6 GB |

## Routing Matrix

| Task Type | Model | Why |
|-----------|-------|-----|
| Code generation | Spark-X2.5-4B | SWE-Bench Pro 44.4, reasoning-first |
| Code review | Ornith-1.0-9B | Self-scaffolding, SWE-Bench Verified 69.4 |
| Multi-file refactoring | Ornith-1.0-9B | Dense 9B, larger effective context |
| Quick edits | LFM2.5-2.6B | 189 t/s, minimal overhead |
| Architecture/design | Spark-X2.5-4B | Reasoning mode, agentic benchmarks |
| Embeddings | LFM2.5-2.6B (port 8081) | Fast, small model, --pooling mean |

## Harness Configuration

### Pi (`~/.pi/agent/models.json`)
- Provider: `llamacpp-local` (baseUrl: `http://127.0.0.1:8080/v1`)
- Default model: `spark-x2.5-4b`
- Default thinking level: `high`
- All models listed above configured

### OMP (`~/.omp/agent/models.json`)
- Same provider configuration as Pi

### zvec-grep
- Index location: `.zg/` under project root
- Default embedding model: `local/potion-code-16m-v2` (downloads and runs locally)
- Custom endpoint: `--endpoint http://127.0.0.1:<port>/v1 --allow-remote`
- Known issue: zg commands intermittently fail via `shell_command` — workaround: `node ~/Downloads/Local-Models/llama.cpp-spark/.../node_modules/@zvec/zvec-grep/dist/cli/index.js <args>`

## Known Issues

1. **Spark llama.cpp fork build**: Custom build at `~/Downloads/Local-Models/llama.cpp-spark/` — must rebuild after llama.cpp updates
2. **LFM pooling**: `--pooling mean` is required; default `none` causes OpenAI API errors
3. **System llama-server rebuild**: `omarchy update` rebuilds `llama.cpp-cuda` from source (slow). Solution: add `IgnorePkg = llama.cpp-cuda` to `/etc/pacman.conf` under `[options]`. Command: `sudo sed -i '/^\[options\]/a IgnorePkg = llama.cpp-cuda' /etc/pacman.conf`. NOTE: modifying `omarchy-update-aur-pkgs` directly does NOT work — it's a symlink owned by the `omarchy-dev` package and gets overwritten on update.
4. **Context overflow**: Pi/OMP system prompts consume 18-34K tokens. Spark at 32K context hits overflow with large task prompts. Use trimmed prompts (~1-2K tokens) and let the harness read files itself

## Change Log

| Date | Change | Notes |
|------|--------|-------|
| 2026-09-02 | S225: All models downloaded, harnesses configured | Initial setup |
| 2026-09-03 | S226: Spark server started, LFM embeddings tested | --pooling mean discovered |
| 2026-09-04 | S226: Model documentation created | This file |
