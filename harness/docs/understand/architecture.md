# GN Harness Architecture

## Runtime
```
main.rs
 - config::load() -> Config
 - terminal::run(config) -> TUI event loop
   - AppState owns Pane list
   - handle_key binds panes
   - agent lifecycle managed via agent.rs
     - spawn/request/recv/stop per AgentConfig
     - stdout/stderr/task channels
   - optional herdr pane control via Unix socket
     - list/create/destroy/input/output
```

## Config model
`src/config.rs` current surface:
- terminal: font, font_size, theme
- panes: layout by group + pane list
- agents: command/env/working_dir per agent preset
- keybindings
- gnhf: agent/max_iterations/stop_condition/worktree_dir
- no_mistakes: repo_path/gate_on_merge

## Execution facts
- ACP over stdio, single request/response id matcher
- 30s hard timeout per request
- stderr logged as agent-named output