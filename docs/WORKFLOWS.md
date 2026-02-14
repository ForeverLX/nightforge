# Workflows

This repo standardizes a local-first, reproducible Red Team workstation layout on Arch Linux.

Design goals:
- Multi-target project navigation
- Loot triage + credential/token hunting
- Exploit/script editing (bash, Python, PowerShell)
- Log/scan output analysis (nmap/nuclei/burp exports)

## Standard Operator Roots (Host Contract)

These directories are treated as stable roots across profiles and scripts:

- `~/engage` — per-engagement working dirs (scan outputs, tasking notes, scratch)
- `~/loot` — high-sensitivity artifacts (credentials, tokens, dumps, evidence)
- `~/notes` — research notes, methodology, writeups
- `~/exploitdev` — templates, PoCs, harnesses, exploit work
- `~/projects` — source repos (e.g., NightOwl code)

Recommended permissions:
- Keep loot private:
  - `chmod 700 ~/loot`

## tmux Workflows

### Base Operator Session (global)

Script: `scripts/tmux-layout.sh`

Creates/attaches a session intended for general operator work with windows:
- `engage` (cwd: `~/engage`)
- `loot` (cwd: `~/loot`)
- `notes` (cwd: `~/notes`)
- `exploitdev` (cwd: `~/exploitdev`)

Run:
- `./scripts/tmux-layout.sh`

### Engagement Session (per target/client)

Script: `scripts/tmux-engage.sh <engagement-name>`

Creates a structured engagement workspace and per-engagement directories:

Directories:
- `~/engage/<name>`
- `~/loot/<name>`
- `~/notes/<name>`
- `~/exploitdev/<name>`

Session:
- `eng-<name>`

Windows:
- `recon` (2 panes)
- `loot`
- `notes`
- `exploitdev`
- `server`

Run:
- `./scripts/tmux-engage.sh ACME`

tmux navigation reminders:
- Next/prev window: `Ctrl+b n` / `Ctrl+b p`
- List windows: `Ctrl+b w`

## Neovim "Red Team IDE" (minimal)

Neovim stays minimal and uses system tools for speed:
- `fd` for file discovery
- `ripgrep (rg)` for content search
- Telescope provides a UI on top of these tools

Key bindings (leader is Space):
- `Space f f` — find files (fd)
- `Space f g` — live grep (rg)
- `Space f b` — buffers
