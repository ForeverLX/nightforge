# GN Harness Goals

## Purpose
GN harness (`gn`) is a terminal-first agent multiplexer built on:
- libghostty terminal rendering
- ratatui TUI layout
- ACP JSON-RPC agent processes
- herdr IPC for remote pane control

## Non-goals
- OS-level GUI automation
- Cloud-only control plane
- Reimplementation of existing terminal multiplexers

## Design constraints
- 39GB total RAM
- Local runtime target: Qwen3-30B-A3B or equivalent lightweight model
- Token-budget-first context policy
- Filesystem-backed state between iterations