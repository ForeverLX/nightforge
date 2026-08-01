# Graph Report - .  (2026-07-22)

## Corpus Check
- Corpus is ~1,984 words - fits in a single context window. You may not need a graph.

## Summary
- 97 nodes · 194 edges · 12 communities (9 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- HerdrClient & Pane Ops
- Config Defaults & Keybindings
- Terminal UI & Rendering
- Agent Process Lifecycle
- Agent ACP Protocol
- Agent Config & Presets
- Config Loading & Theme
- Agent Process Control
- Config Type Definitions
- Agent Event Channel
- Pane Config Types
- Main Entry Point

## God Nodes (most connected - your core abstractions)
1. `AgentProcess` - 18 edges
2. `Config` - 15 edges
3. `HerdrClient` - 11 edges
4. `AgentConfig` - 9 edges
5. `AcpResponse` - 8 edges
6. `AgentEvent` - 7 edges
7. `AppState` - 7 edges
8. `default_config()` - 6 edges
9. `run()` - 6 edges
10. `AcpError` - 5 edges

## Surprising Connections (you probably didn't know these)
- `AppState` --references--> `Config`  [EXTRACTED]
  src/terminal.rs → src/config.rs
- `run()` --references--> `Config`  [EXTRACTED]
  src/terminal.rs → src/config.rs
- `default_presets()` --references--> `AgentConfig`  [EXTRACTED]
  src/presets.rs → src/config.rs

## Import Cycles
- None detected.

## Communities (12 total, 3 thin omitted)

### Community 0 - "HerdrClient & Pane Ops"
Cohesion: 0.21
Nodes (11): Default, PathBuf, HerdrClient, HerdrResponse, PaneInfo, Option, Result, Self (+3 more)

### Community 1 - "Config Defaults & Keybindings"
Cohesion: 0.22
Nodes (13): default_close_pane(), default_gate_run(), default_gnhf_agent(), default_gnhf_run(), default_new_tab(), default_next_pane(), default_prev_pane(), default_repo_path() (+5 more)

### Community 2 - "Terminal UI & Rendering"
Cohesion: 0.27
Nodes (11): Frame, KeyEvent, AppState, handle_key(), Pane, Result, Self, String (+3 more)

### Community 3 - "Agent Process Lifecycle"
Cohesion: 0.25
Nodes (6): Child, Drop, Receiver, Sender, AgentProcess, Vec

### Community 4 - "Agent ACP Protocol"
Cohesion: 0.50
Nodes (5): AcpError, AcpRequest, AcpResponse, String, Value

### Community 5 - "Agent Config & Presets"
Cohesion: 0.47
Nodes (5): AgentConfig, HashMap, default_presets(), HashMap, String

### Community 6 - "Config Loading & Theme"
Cohesion: 0.33
Nodes (6): default_config(), default_font(), default_font_size(), default_theme(), load(), Result

### Community 8 - "Config Type Definitions"
Cohesion: 0.40
Nodes (5): Config, GnhfConfig, Keybindings, NoMistakesConfig, TerminalConfig

### Community 10 - "Pane Config Types"
Cohesion: 1.00
Nodes (3): PaneGroup, PanesConfig, Vec

## Knowledge Gaps
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AgentConfig` connect `Agent Config & Presets` to `Config Defaults & Keybindings`, `Agent ACP Protocol`, `Agent Process Control`, `Config Type Definitions`, `Pane Config Types`?**
  _High betweenness centrality (0.308) - this node is a cross-community bridge._
- **Why does `Config` connect `Config Type Definitions` to `Config Defaults & Keybindings`, `Terminal UI & Rendering`, `Agent Config & Presets`, `Config Loading & Theme`, `Pane Config Types`?**
  _High betweenness centrality (0.200) - this node is a cross-community bridge._
- **Why does `AgentProcess` connect `Agent Process Lifecycle` to `Agent Event Channel`, `Agent ACP Protocol`, `Agent Process Control`?**
  _High betweenness centrality (0.154) - this node is a cross-community bridge._