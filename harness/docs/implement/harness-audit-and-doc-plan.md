# GN Harness Audit and Doc Plan

**Scope:** Map the current `~/Github/nightforge/harness` code state, surface gaps,
define publish-ready documentation structure, and fix any variances against source code.

**Ground truth:** `Cargo.toml`, `src/main.rs`, `src/config.rs`, `src/agent.rs`,
`src/presets.rs`, `src/terminal.rs`, `src/herdr.rs`.

---

## 1. Real-World Audit Matrix (Current State)

| Layer | Present? | Source of truth | Gap |
|---|---|---|---|
| Terminal UI | ✅ | `src/terminal.rs` | Missing pane output stream wiring |
| Config system | ✅ | `src/config.rs` | No runtime reload; only one config path |
| Agent presets | ✅ | `src/presets.rs` | Prompt text not externalized |
| ACP client | ✅ | `src/agent.rs` | No structured tool registry |
| Herdr client | ✅ | `src/herdr.rs` | Assumes single socket |
| Prompt layer | ❌ | — | No `prompts/` directory |
| Context/compaction | ❌ | — | No token budget or summarizer |
| Loop state | ❌ | — | No plan/scratchpad policy |
| Approval/safety | ❌ | — | No permissions matrix |
| Observability | ❌ | — | No tracing or cost/latency capture |

---

## 2. Execution Flow (Current Truth)

```
main.rs: load config
 -> terminal.rs: run TUI loop
   -> config presets define agent entries
     -> agent.rs: spawn agent process
       -> herdr.rs: optional remote pane driver
```

What is missing:
- prompt load per-preset before spawn
- token budget check before each request
- compact history after each observation
- verification gate before next action

---

## 3. File Map for Documentation

```text
docs/
  understand/
    goals.md
    architecture.md
  implement/
    prompt-layer.md
    context-layer.md
    loop-layer.md
    safety-layer.md
  operate/
    onboarding.md
    troubleshooting.md
    release-checklist.md
handbook.md
research/ai-agent-engineering-best-practices-2026.md
```

---

## 4. Priority Fixes (Tied to Code)

1. `src/presets.rs` — Extract prompt text into external files under `prompts/`.
2. `src/terminal.rs` — Wire agent pane output stream and state refresh.
3. `src/config.rs` — Add runtime reload hook for non-TUI test environments.
4. `src/agent.rs` — Add tool schema registry before next harness abstraction.
5. `src/herdr.rs` — Make socket path configurable per preset.

---

## 5. Diagram Design Pact

- Architecture diagram: `prompts/` + `handbook.md` state source for shapes.
- Loop diagram: exact control flow present in `src/agent.rs`.
- Safety matrix: exact rules present in future `src/permissions.rs`.

No diagram should assume functionality that does not exist in `src/`.

---

## 6. Publish Sequence

1. Commit research/handbook annex.
2. Implement prompt externalization.
3. Implement pane output wiring.
4. Add loop state layer.
5. Add approval gate.
6. Publish docs.
7. Freeze version.
