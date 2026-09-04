# S226 — NightForge → Omarchy Migration: Split Prompt Manifest

> Split from `nightforge-omarchy-migration-prompt.md` (91 lines, too large for 32K context).
> Each task below is self-contained, highly-specced, and routed per the S225 routing matrix.

## Task Summary

| ID | Phase | Title | Model | Harness | Context Est. |
|----|-------|-------|-------|---------|-------------|
| A1 | Audit | Audit dotfiles/ inventory | Ornith-1.0-9B | Pi | ~4K |
| A2 | Audit | Audit scripts/ for Niri refs | Ornith-1.0-9B | Pi | ~5K |
| A3 | Audit | Audit Go services + CUE schemas | Ornith-1.0-9B | Pi | ~7K |
| A4 | Audit | Backup configs & snapshot | Spark-X2.5-4B | Prime Agent | ~3K |
| B1 | Setup | Research Omarchy + Aether defaults | Spark-X2.5-4B | Pi | ~4K |
| B2 | Setup | Risk assessment | Ornith-1.0-9B | Pi | ~4K |
| C1 | Migrate | Port keybindings Niri → Hyprland | Spark-X2.5-4B | Pi | ~10K |
| C2 | Migrate | Port window rules Niri → Hyprland | Spark-X2.5-4B | Pi | ~12K |
| C3 | Migrate | Port compositor config | Spark-X2.5-4B | Pi | ~8K |
| C4 | Migrate | Port autostart spawns | Spark-X2.5-4B | Pi | ~5K |
| C5 | Migrate | Migrate theming matugen → Aether | Spark-X2.5-4B | Pi | ~20K |
| C6 | Migrate | Migrate CUE schemas to Hyprland | Ornith-1.0-9B | Pi | ~12K |
| C7 | Migrate | Migrate Go CUE tools | Ornith-1.0-9B | Prime Agent | ~18K |
| C8 | Migrate | Migrate Niri-dependent scripts | Spark-X2.5-4B | Pi | ~12K |
| D1 | Migrate | Migrate quickshell → Waybar | Spark-X2.5-4B | Pi | ~18K |
| D2 | Migrate | Update deployment scripts | LFM2.5-2.6B | Pi (one-shot) | ~8K |
| E1 | Validate | Integration testing | Ornith-1.0-9B | OMP | ~5K |
| E2 | Validate | Cleanup Niri artifacts | Spark-X2.5-4B | Pi | ~5K |

**Phase F (parallel):** Model quality testing per `s225-model-harness-test-plan.md` and routing matrix. Use Spark for code generation tasks, Ornith for review, LFM2.5-2.6B for quick edits. Documented in the handoff — no split prompt needed.

## Routing Rationale

- **Audit tasks (A1-A3)**: Ornith-1.0-9B — detail-oriented, systematic, multi-file analysis
- **Setup/research (B1)**: Spark-X2.5-4B — reasoning-first, architecture/design analysis
- **Risk assessment (B2)**: Ornith-1.0-9B — systematic analysis, identifies all edge cases
- **Config migration (C1-C4)**: Spark-X2.5-4B — best SWE-Bench Pro (44.4), reasoning-first, strongest code generation for config format mapping
- **Theming (C5)**: Spark-X2.5-4B — complex multi-output script rewrite, architecture work
- **CUE/Go tooling (C6-C7)**: Ornith-1.0-9B — multi-file refactoring across cmd/ and internal/, needs consistency across many files
- **Niri scripts (C8)**: Spark-X2.5-4B — IPC call porting (niri msg → hyprctl dispatch), similar to C1/C2
- **Quickshell → Waybar (D1)**: Spark-X2.5-4B — large code generation (QML → JSON/CSS)
- **Deployment scripts (D2)**: LFM2.5-2.6B — quick edits, simple string replacements, 189 t/s
- **Testing (E1)**: Ornith-1.0-9B — systematic debugging and validation, SWE-Bench Verified 69.4
- **Cleanup (E2)**: Spark-X2.5-4B — multi-file changes, needs to understand all Niri refs

## Execution Order

```
A1 → A2 → A3 → A4
                 → B1 → B2
                       → C1 → C2 → C3 → C4
                          ↓
                          C5 → C6 → C7 → C8
                                         ↓
                          D1 → D2 → E1 → E2
```

- Phase A (A1-A4) can run sequentially (each builds context for the next).
- B1 and B2 can run in parallel with A4 completion.
- C1, C2, C3, C4 are independent (different Hyprland config files) — can run in parallel.
- C5 depends on C3 (needs input/looknfeel to know color integration points).
- C6 depends on C1, C2, C3 (needs Hyprland equivalents defined first).
- C7 depends on C6 (Go tools read CUE schemas).
- C8 can run in parallel with C6, C7 (different file domains).
- D1 depends on C1-C3 (needs keybinding/window-rule decisions).
- D2 is independent (simple package list changes).
- E1 depends on all C/D tasks.
- E2 depends on E1.

## Context Budget Notes

- All tasks designed for 32K context window (Spark/Ornith).
- Each prompt file includes inline code context so the model need not read additional files.
- Largest task: C5 (~20K tokens) — includes matugen-sync.sh excerpts + Aether API. Still fits in 32K.
- Tasks marked "Large" should use Prime Agent or Pi with extended attention.
- Phase F model quality testing is documented separately in `s225-model-harness-test-plan.md` (S225 handoff).