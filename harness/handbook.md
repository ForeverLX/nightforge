# GN Harness Handbook — Prompt, Context, Loop, and Harness Engineering

**Scope:** This is the integration guide for `~/Github/nightforge/harness`.
It translates high-quality external research into concrete implementation decisions
for the GN harness (`gn`) runtime.

**Truth tests:** This handbook must stay consistent with:
- `src/main.rs`
- `src/config.rs`
- `src/agent.rs`
- `src/presets.rs`
- `src/terminal.rs`
- `src/herdr.rs`
- `Cargo.toml`

If any live code diverges from this document, update the document first, then edit implementation.

---

## 1. Prompt Engineering for Local Agents

### Minimal viable prompt contract for this repo
Store all prompts as versioned files under `prompts/`. Do not inline prompt text in code.

Recommended structure:
```text
role
rules
examples
task
output schema
quality gate
```

### Rules that fit this stack
- Role anchor first, positive rules, negative list only after positive rules.
- Limit every prompt to one mode of behavior. Detection + mitigation + formatting in one prompt often trains conflict.
- Quality gate should be a 3-axis rubric, not a yes/no final check.

### Agent-specific rules
- Hermes/OMP/Zero prompts must state: “Do not rely on hidden memory. Read state from filesystem.”
- Agent prompts must include a hard worktree or sandbox path and a hard timeout before first tool call.
- Preset prompts must be identical except for model/runtime args; prompt drift between presets is a regression risk.

### Ponytail check
- Use one shared prompt skeleton.
- No per-prompt playbook files.
- No prompt template engine unless more than 3 prompts require conditional branches.

---

## 2. Context Engineering — Token Budget Rules for Local Runs

### Observed constraints
- Runtime: llama-server on `:8081`.
- Model: Qwen3-30B-A3B Q4_K_M.
- Effective measured decode speed: ~11.1 tok/s.
- Confirmed effective RAM: 39GB total, not 64GB.
- Do not design volumes for 64GB+ workloads.

### Must-add contract
1. Every agent request has a hard token budget: system + tools + retrieved + history + output reserve.
2. Prefix stability is the priority. System instructions and tool schemas must not be rebuilt per request.
3. Conversation history is compressed after response; keep plan file and scratchpad on disk.

### Tool-result handling
- Strip tool stdout/stderr to head + summary + tail before reinjection.
- Do not dump full logs into conversation history.
- Log raw tool output to filesystem only.

### Retrieval rules
- Select by step, not by volume.
- Chunk size: prefer shorter chunks over larger contexts.
- Do not retrieve full project files unless current step requires them.

### Ponytail check
- No custom compaction tier beyond: stable prefix, step retrieval, head/tail tool output, scratchpad file.
- No dependency additions just for RAG unless the current retrieval path is measurably failing.

---

## 3. Harness Engineering — GN Runtime Constraints

### Current truth
The runtime is an early stage TUI + agent process manager with:
- Static presets in `src/presets.rs`
- ACP over stdio in `src/agent.rs`
- TUI panes in `src/terminal.rs`
- Herdr client in `src/herdr.rs`
- Config largely hardcoded with one config path

### Component audit
| Component | Status | What it needs |
|---|---|---|
| System prompt / AGENTS.md | Partial | Per-preset prompt files + cache-stable prefix |
| Tool / MCP surface | Not implemented | Tool registry + schema files |
| Orchestration / subagents | Partial | Worktree isolation + spawn policy |
| Hooks / middleware | Not implemented | Pre/post execution guards |
| Compaction | Not implemented | Scratchpad + step summaries |
| Skills / progressive disclosure | Not implemented | Per-preset capability manifest |
| Observability | Not implemented | Trace + token + cost meter |
| Approval / safety | Not implemented | Tiered permissions + approval gate |

### Non-goals for this repo
- Full OS-mode computer control.
- GUI DOM automation.
- Multi-machine orchestration.
- Cloud-only runtime paths.

### Ponytail check
- Capture real traces before extracting more metrics.
- Add one missing piece at a time; prefer stability over feature count.

---

## 4. Loop Engineering — Policy for This Stack

### Required loop primitives
1. Task declaration with verifiable completion condition.
2. Filesystem-backed plan file the agent reads and checks off.
3. Filesystem-backed scratchpad reviewed before each iteration.
4. Explicit iteration and time limits, never infinite loops.
5. No-progress detection: same failing tool, same file edit loop, unchanged breadcrumbs.

### Termination contract
Retry policy:
- Permitted: transient tool failures, missing cached content, local compilation errors.
- Breaks: missing runtime dependency, missing IPC target, auth failure, unsafe command.

### Escalation
First escalate when:
- Task requires multi-domain judgment not supported by current prompt.
- Approver is needed for destructive action.
- Loop exceeds defined budget.

### Ponytail check
- Do not add reflection subsystems before a verification test exists.
- Add one stop condition at a time and observe behavior.

---

## 5. Implementation Priority

1. **Prompt layer**
   - Add `prompts/` directory.
   - Move preset-specific prompt text out of `src/presets.rs`.
   - Implement cache-stable prefix loading.

2. **Context layer**
   - Implement token budget check before each agent request.
   - Implement tool-result truncation policy.

3. **Loop state layer**
   - Add plan file support to terminal pane view.
   - Add per-task scratchpad path.

4. **Safety layer**
   - Add destructive-action guard.
   - Add max iteration and wall-clock exits.

5. **Observability**
   - Add latency/token/cost tracking.

6. **Skills / MCP support**
   - Add tool registry with schema discovery.

---

## 6. Verification Checklist

- [ ] Prompts are versioned and reviewable.
- [ ] Prefix cache hit ratio is constant.
- [ ] Token count is within explicit budget before every model call.
- [ ] History length is bounded and older turns are compacted.
- [ ] Plan file exists and is read at task start.
- [ ] Scratchpad exists for long-running tasks.
- [ ] Stop conditions behave correctly on 3 simulated failure modes.
- [ ] Destructive action prompts for approval or blocks silently.
- [ ] Trace output includes: prompt tokens, completion tokens, latency, tool call count, exit reason.

---

## Sources
- Anthropic Prompting Best Practices, 2026
- OpenAI Prompt Engineering Guide, 2026
- LangChain Context Engineering for Agents, 2026
- LangChain Anatomy of an Agent Harness, 2026
- Martin Fowler Harness Engineering, 2026
- Rajshah4 harness-engineering repo, 2026
- Kanak Malpani loop engineering material, 2026
- Addy Osmani Agent Harness Engineering, 2026
- Open Interpreter terminal harness docs, 2026
- Loop Engineering Manifesto, 2026
- arxiv 2507.13334 Context Engineering survey
- arxiv 2605.23296 Parallel Context Compaction
- Chroma Research Context Rot, 2025
