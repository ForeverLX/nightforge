# Profiles

Profiles define reproducible workstation personas. Each profile maps to one or more package manifests
and a predictable workflow layout.

Design principles:
- Local-first by default (OPSEC)
- Minimal and VM-friendly
- Profiles are composable and auditable (manifests + scripts + docs)
- Workflows focus on operator reality: loot triage, navigation, scripting, and log analysis

## Profiles

### 1) local-only
Purpose:
- Minimal baseline
- No team tooling assumptions
- Safe starting point for VM or fresh installs

Install:
- `./install.sh --profile local-only`

Includes:
- zsh + core CLI stack
- neovim (minimal)
- yazi/fzf/rg/fd/zoxide/bat

### 2) solo-operator
Purpose:
- Daily-driver profile (local-first)
- Optimized for a single operator’s speed and workflow

Terminal:
- Ghostty

Install:
- `./install.sh --profile solo-operator`

Includes:
- local-only + Ghostty
- tmux is expected as a workflow tool (already installed on many systems; included in team profile)

### 3) team-operator
Purpose:
- Production-grade defaults for repeatability and standardization
- Designed for onboarding + consistent sessions

Terminal:
- Kitty

Install:
- `./install.sh --profile team-operator`

Includes:
- local-only + Kitty + tmux
- standardized tmux layouts and directory contract

## Notes on install behavior

- Installer is interactive by default:
  - `./install.sh --profile <name>`
- Unattended mode:
  - `./install.sh --profile <name> --yes`
- Preview without changes:
  - `./install.sh --profile <name> --dry-run`

Dotfiles are applied separately:
- `./scripts/apply-dotfiles.sh`
