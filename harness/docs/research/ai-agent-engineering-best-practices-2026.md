# AI Agent Engineering Best Practices — June/July 2026

**Source quality bar:** official docs, peer-reviewed papers, production write-ups from OpenAI/Anthropic/Google/LangChain/Martin Fowler, and verified benchmark results. Nothing from marketing gloss.

## 1. Prompt Engineering — What Still Works in Mid-2026

### Consensus primitives
- Be clear and direct; positive instructions beat negative ones.
- Use examples; 3–5 diverse few-shot examples remain one of the highest-signal moves.
- Structure with XML or Markdown headings to separate instructions, context, examples, output contract.
- Give the model a role; one sentence of persona changes behavior measurably.

### Framework comparison
| Framework | Shape | Best for |
|---|---|---|
| APE | Action + Purpose + Expectation | Fast, routine tasks |
| CO-STAR | Context, Objective, Style, Tone, Audience, Response | Content and comms |
| RISEN | Role, Instructions, Steps, End goal, Narrowing | Complex multi-step work |
| RAILS | Role, Architecture, Instructions, Loop, Safety | Reusable production prompts |

### 2026 shifts
- **Reasoning models don't want chain-of-thought choreography.** GPT-5-series and Gemini 3 reward goal statements, not "think step by step." Claude Opus 5 prefers adaptive thinking + lower effort; explicit verification instructions can force over-checking.
- **Prompt length sweet spot is still ~150–300 words for most tasks.** Degradation starts well before hard context limits; 16K curated tokens often beat 128K dumped tokens.
- **Prefill / start-with-the-answer is underused.** Anchoring the response shape in the first 1–2 lines is one of the cheapest format fixes.
- **Self-critique loop is the highest-leverage missing move.** A 3-axis rubric + “revise if below threshold” catches format drift, unsupported claims, and filler better than prompt patching.

### Verified tests/results
- Anthropic/Official: clear structure + examples + thinking control outperforms verbose prompting on agentic tasks.
- Multiple 2024–2026 studies: prompt engineering improves performance by **20–40%** on benchmarked tasks.
- Zero-shot CoT often approaches few-shot CoT on reasoning tasks; few-shot wins on style/labeling precision.

### Actionable rules for the harness
1. Store prompts as versioned files, not chat history.
2. Use a shared prompt skeleton: role → rules → examples → task → output schema → quality gate.
3. Pin model snapshots for production prompts; revalidate after every model version change.
4. Add a self-check rubric only for high-stakes outputs; don't pay the tokens on trivial calls.

---

## 2. Context Engineering — The 2026 Production Playbook

### Core principle
Context quality > prompt wording. Output quality tracks context quality more than anything else.

### 4 strategies from LangChain
| Strategy | What it is | When to use |
|---|---|---|
| Write | Persist intermediate state to files | Long-horizon agents, audits |
| Select | Retrieve only what the current step needs | Every agent loop |
| Compress | Summarize / offload / truncate old turns | When context pressure rises |
| Isolate | Separate concerns into subfiles/agents | Multi-domain work |

### Ordering and caching signals
- Stable system prompt + tool schemas + few-shot block first; variable retrieved docs + user turn + tool results last.
- Stable prefix = prompt cache hit on OpenAI, Anthropic, Gemini. Cache-happy ordering reduces latency and cost.
- Lost-in-middle effect is real: models weight start and end more than middle. Put the current task and highest-value evidence at end.

### Verified tests/results
- **Context rot is measurable:** Chroma 2025 showed serious accuracy degradation before hard context limits; 200K windows degrade around 50K input tokens.
- **Structured coherent text can degrade attention more than shuffled snippets** under long context. Do not assume tidy PDF ingestion is safe.
- **Hybrid RAG + long-context reasoning is the 2026 default.** Pure RAG and pure long-context both lose; the winning pattern is retrieve 50K–200K relevant tokens, then reason.
- Parallel compaction research (arxiv May 2026) showed summarization-blocked inference stalls for tens of seconds; parallel compaction improves throughput and predictability.
- CAG / prompt caching saves real money when prefix is stable.

### Actionable rules for the harness
1. Budget context per route: system prompt cap, retrieved chunk cap, history cap, output reserve.
2. Cache the prefix; never reorder or rebuild stable blocks per-request.
3. Trim tool outputs before reinserting: keep head/tail + summary, drop repeated boilerplate.
4. Keep a scratchpad / plan file on disk so compaction doesn’t erase working state.
5. Treat “add more context” as a regression risk, not a fix.

---

## 3. Harness Engineering — Building Agent Infrastructure

### Definition
Agent = Model + Harness. The model provides intelligence; the harness provides state, tool execution, feedback loops, enforcement, and interface.

### Core harness components
| Component | Responsibility |
|---|---|
| System prompt / AGENTS.md | Stable behavior, conventions, project rules |
| Tools + MCPs | Typed actions the model can call |
| Orchestration | Subagent spawn, routing, worktree isolation |
| Hooks / middleware | Deterministic checks before/after actions |
| Compaction | Bounded context across long sessions |
| Skills / progressive disclosure | Load instructions only when needed |
| Observability | Traces, spans, token/cost/latency metering |
| Approval + safety | Permission matrix, destructive-action guards |

### Production harness evidence
- **OpenAI internal writeup:** main bottleneck was environment underspecification, not model capability. Harness fixes unlock order-of-magnitude velocity.
- **Terminal Bench 2.0 finding:** same model in a different harness moves Top 30 → Top 5.
- **Martin Fowler (April 2026):** harness engineering is now a distinct discipline. Two controls: guides (feedforward) and sensors (feedback). Computational sensors are cheap; inferential sensors add semantic judgment.
- **Open Interpreter:** harness emulation lets low-cost models match expensive-model behavior by changing prompt shape, tool schema, and message conversion, not weights.

### Harnessability signals
- Strongly typed languages, module boundaries, and test suites make a codebase more harnessable.
- Service templates + architecture docs reduce agent guesswork.
- Custom linters that embed remediation instructions act as “positive prompt injection” at build time.

### Actionable rules for the harness
1. Make every rule mechanical: if a convention matters, encode it in a linter or hook.
2. Treat `AGENTS.md` and repo docs as first-class code; update them when behavior changes.
3. Prefer shared tooling over hand-rolled helpers; centralize invariants.
4. Design for filesystem-first state: durable artifacts > hidden conversation state.
5. Add observability before scaling breadth; trace-driven improvement beats vibes.

---

## 4. Loop Engineering — Autonomy, Recovery, and Stop Conditions

### Definition
Loop engineering is the discipline of designing the repeat cycle around the model: prompt → act → observe → verify → compact → continue, with explicit exits.

### Canonical patterns
| Pattern | Shape | When to use |
|---|---|---|
| ReAct | Thought → Action → Observation | Short exploratory tasks |
| Plan-and-Execute | Plan upfront, execute steps | Predictable cost needed |
| Reflection | Generate → Evaluate → Revise | High-stakes outputs |
| Ralph Loop | Fresh-context rerun with filesystem state | Overnight / long-horizon |
| PreFlect | Prospective critique before action | Plan fragility is the main risk |

### 2026 production patterns
- **Ralph Wiggum Loop** is the overnight primitive: hook exits, re-inject goal, start clean context, read state from filesystem. Simple, reliable, model-agnostic.
- **Prospective reflection beats retrospective correction.** PreFlect shows gains by critiquing plans before execution, then doing dynamic re-plan on deviation.
- **Reflexion in production:** generator + evaluator + reflector with episodic memory improves output quality by ~34% at ~1.6× token cost. Evaluator/reflector should use lower temperature than generator.
- **Stop conditions must be explicit.** Max iterations, wall-clock, token budget, cost budget, task-completed signal, and escalation path.

### Verified tests/results
- Reflexion pattern: 34% output quality improvement, 1.6× token overhead.
- Terminal Bench 2.0 harness-only changes can move agents 25+ ranking positions without model changes.
- Parallel compaction reduces end-to-end wall time vs sequential compaction in agent traces.

### Actionable rules for the harness
1. Enforce budgets every turn: steps, time, tokens, cost.
2. Detect no-progress paths: same tool failing 3×, same file edited in circles, or breadcrumbs unchanged.
3. Use filesystem state between loop iterations, not conversation memory.
4. Make verification the exit condition: tests pass / schema valid / acceptance checklist green.
5. Keep a cleanup/reset path before retry; failed trajectories must not poison live state.

---

## 5. What To Build Next in the Harness

### Priority order
1. **Prompt/context assembly layer** — prefix cache stability + token budgets + compact tool outputs.
2. **Verification hooks** — linter/test gate after edits; destructive-action guard before shell.
3. **Filesystem-backed loop state** — plan file + scratchpad + episodic reflection file.
4. **Observability** — traces, latency, token/cost per task.
5. **Skill/progressive disclosure** — load instructions and tools only when needed.

### Evaluation infra
- Build prompt/loop tests before adding more prompts. Measure: task success rate, token usage, time-to-complete, failure taxonomy.
- Run shadow mode before production; pin model snapshots.

---

## Sources
- Anthropic Prompting Best Practices, 2026
- OpenAI Prompt Engineering Guide, 2026
- Google Vertex Prompting Strategies, 2026
- LangChain Context Engineering for Agents, 2026
- LangChain Anatomy of an Agent Harness, 2026
- Martin Fowler Harness Engineering, 2026
- OpenAI Harness Engineering internal writeup, 2026
- Open Interpreter Harness docs, 2026
- arxiv 2507.13334 Context Engineering survey
- arxiv 2605.23296 Parallel Context Compaction
- arxiv 2026 ACL SARA: Selective and Adaptive RAG
- Chroma Research Context Rot, 2025
- Rajshah4 harness-engineering repo, 2026
- Kanak Malpani loop engineering material, 2026
- PreFlect arxiv 2602.07187
- Reflexion NeurIPS 2023 + production notes
