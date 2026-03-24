# NightForge — Operator Workstation CLAUDE.md

## What This Repo Is
NightForge is Darrius's operator workstation configuration — dotfiles, shell config,
window manager, editor, and tooling. Every line in this repo was deliberately chosen.
Darrius built this system and owns every decision in it. The build process itself is
part of the portfolio signal.

## System Profile
- **OS:** Arch Linux (x86_64)
- **WM:** Niri (Wayland compositor)
- **Shell:** Zsh + Starship prompt
- **Editor:** Neovim
- **Search:** ripgrep (`rg`) — always use `rg`, never `grep -E`
- **WireGuard IP:** 10.0.0.3 (Veil mesh node)

## What Claude Code May Do in This Repo
- Read any config file to understand the current setup
- Explain what a config block does and why it behaves a certain way
- Identify bugs or conflicts in existing config Darrius has written
- Suggest changes with full explanation of the mechanism and tradeoff
- Review shell scripts Darrius has written — explain issues, never rewrite unprompted
- Update README and documentation

## What Claude Code Must Never Do in This Repo
- Generate new dotfiles, shell configs, Niri config, or Neovim config unprompted
- Rewrite existing config even if asked to "improve" it — suggest specific changes only
- Add plugins, packages, or dependencies without Darrius explicitly requesting them
- Assume any config decision was accidental — ask before suggesting it's wrong
- Use `grep` — always use `rg`

## Review-Only Principle
NightForge config is skill-building territory. Darrius writes, Claude reviews.
If asked to generate config from scratch, decline and ask Darrius to write a first
draft instead. The goal is understanding, not output.

## Key Config Areas
- Zsh config — shell behavior, aliases, functions
- Starship — cross-node prompt consistency, version controlled
- Niri — Wayland compositor config
- Neovim — editor config
- SSH config — `~/.ssh/config` defines host aliases for all Veil nodes
- WireGuard — `/etc/wireguard/wg0.conf` (never edit directly)
- nftables — `/etc/nftables.conf` (never edit directly)

## Commit Convention
Format: `type(scope): subject` — types: `feat` `fix` `docs` `chore` `refactor` `security` `infra`
Imperative mood, no period, under 72 characters.
Never auto-push — stage and show diff, Darrius approves before any push.

## .claude/ Note
`.claude/` is gitignored in this repo. Backup lives at `~/Documents/azrael-ops/claude/` on Gitea.
Never commit `.claude/` contents here.
