# Arch Niri Offensive Security Workstation

## Executive Summary
This repository documents the build, configuration, and operational framework of my daily-use offensive security workstation running Arch Linux with the Niri compositor. The project emphasizes reproducibility, operational awareness, OPSEC-safe workflows, and long-term maintainability suitable for professional offensive security research and engagement work.

Rather than treating the workstation as a disposable lab, this project approaches it as a persistent operational platform: changes are measured, documented, validated, and versioned. The result is a stable, secure, and contextually-aware environment that supports exploit development, reverse engineering, Active Directory attacks, and assessment workflows without sacrificing usability.

## 🎯 Operator Terminal Framework (NEW - v0.5.0)

**Contextual awareness system** that provides instant operational intelligence on terminal startup:

### Features
- **VPN Detection**: HTB, TryHackMe, Proxmox VPN status and IP
- **Engagement Context**: Auto-detects when working in `~/engage/` directories
- **Network Awareness**: Local IP, interface speed, network type (lab/internal/public)
- **Container Status**: Active Podman profiles and container count
- **Git Context**: Current repository, branch, and uncommitted changes
- **MITRE Logging**: `mitre log T1234 "technique"` for ATT&CK tracking
- **System Health**: Package count, disk usage, memory, uptime

**Startup time: <100ms** - Fast, lightweight, modular design.

### Quick Demo
```bash
# New terminal shows:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RED TEAM OPERATOR
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[System info table with custom logo]

[~] Network: HTB Lab (10.10.14.5)
[✓] VPN: Connected via tun0
[⚡] ENGAGEMENT: client-2025 (active)
[→] Target: 192.168.1.0/24
[⚔] MITRE: 8 techniques logged
[✓] Git: offsec-workstation (main) - clean
```

**Documentation**: See [docs/OPERATOR-TERMINAL.md](docs/OPERATOR-TERMINAL.md)

---

## 🐳 Container Profiles (v0.4.0)

**Rootless Podman container profiles** for isolated offensive security workflows. Each profile is minimal, reproducible, and built from version-controlled manifests.

### Available Profiles
- **toolbox**: Base Arch Linux with Python runtime (~1.1 GB)
- **ad**: Active Directory engagement tooling (~1.3 GB)
- **re**: Reverse engineering & vulnerability research (~1.8 GB)
- **web**: Web reconnaissance & enumeration (~1.1 GB)

### Quick Start
```bash
# Build all profiles
./modules/container/scripts/container.sh build-all

# Run a profile (automatically mounts engage/loot/notes/exploitdev/projects)
./modules/container/scripts/container.sh run ad

# Export for air-gapped engagements
./modules/container/scripts/container.sh export ad
```

**Documentation**: See [docs/CONTAINER.md](docs/CONTAINER.md) and [docs/CONTAINER-QUICKREF.md](docs/CONTAINER-QUICKREF.md)

---

## 🪟 Niri Compositor (v0.5.0)

**Modern Wayland compositor** with unique features for multi-tasking offensive work:

### Why Niri?
- **Scrolling layout**: Windows never resize unexpectedly - scroll through unlimited workspace width
- **Built-in overview**: Dynamic workspace switcher (like GNOME) with visual preview
- **Per-monitor workspaces**: Independent workspace sets on each display
- **Focus-or-spawn**: Smart window management - focus if exists, spawn if not
- **Better Wayland support**: Native color management, fractional scaling, superior trackpad gestures

### Key Integrations
- **DMS (Dank Material Shell)**: Unified bar, launcher, system tray, wallpaper management
- **Hybrid keybinds**: Vim-style navigation (Mod+H/J/K/L) with custom focus-or-spawn scripts
- **Theme switching**: Quick toggle between OPSEC dark/light modes
- **Multi-monitor**: Full support with mixed DPI/scaling (4K + 1080p tested)

**Migration from Sway**: See [docs/NIRI-MIGRATION.md](docs/NIRI-MIGRATION.md)

---

## Visual Configuration

### Window Transparency
The workstation uses tasteful transparency for a modern, layered aesthetic while maintaining full readability:

- **Terminals (Ghostty)**: 55% opacity - Shows wallpaper context without sacrificing readability
- **Browsers**: 100% opacity - Full clarity for web application testing
- **Notes (Obsidian)**: 90% opacity - Balanced for extended reading/writing
- **File managers**: 85% opacity - Functional transparency
- **System monitors**: 80% opacity - See underlying activity

**Demo Mode**: For client presentations, run `niri-theme demo` to disable all transparency.

**Rationale**: Transparency aids workflow awareness (seeing underlying context), follows industry standards (macOS, iTerm2), and is common in offensive security culture. All text remains fully readable.

---

## Why This Matters

Offensive security tooling is often demonstrated in disposable or undocumented environments. In practice, professional offensive work depends on systems that are stable, predictable, and trustworthy over time.

This project matters because it treats the workstation itself as part of the attack surface and the workflow:

- **Operational awareness**: Terminal framework provides instant VPN, engagement, and network context
- **Reduced ambient risk**: Fewer unnecessary packages, services, and network features means fewer unintended behaviors on hostile networks
- **Reproducibility**: Version-controlled configs, automated audits, containerized workflows
- **OPSEC awareness**: MITRE logging, engagement tracking, demo mode for client work
- **Long-term maintainability**: The system is designed to evolve safely, not require periodic rebuilds

## Who This Is For

**Recruiters / Hiring Managers:**
A concrete example of operational maturity: context-aware workflows, reproducible infrastructure, OPSEC considerations, and clean documentation. Start with Executive Summary, Operator Terminal Framework, and Container Profiles.

**Offensive Security Practitioners / Red Teamers:**
Practical workstation patterns that reduce friction during engagements: VPN detection, engagement context tracking, MITRE logging, containerized tools, and stable multi-monitor setups.

**Linux / Infrastructure Engineers:**
Documented approach to maintaining a long-lived workstation: package minimization, Wayland compositor configuration, rootless containers, performance baselines, and automated health checks.

## Lab Methodology (Built Environments)

I design and maintain small, isolated lab environments (e.g., Active Directory, Linux, and mixed network setups) to practice realistic offensive workflows against systems I configured myself. Each lab starts from a known baseline, stays within defined scope, and emphasizes minimal validation, evidence capture, and clear remediation-focused reporting.

The focus is not on "winning" challenges, but on repeatable methodology: understanding system behavior, validating impact safely, and documenting findings in a way that would hold up in a real assessment or internal review.

## System Architecture

**Hardware:**
- CPU: Intel i3-10105F (4 cores, 8 threads @ 4.40 GHz)
- RAM: 32GB
- GPU: NVIDIA GTX 1650 (Wayland + nvidia-drm)
- Storage: 512GB NVMe (/) + 512GB NVMe (/home)
- Displays: Dual monitor (supports mixed DPI/scaling)

**Software Stack:**
- OS: Arch Linux (rolling release)
- Compositor: Niri 25.11 (Wayland)
- Terminal: Ghostty 1.2.3
- Shell: Zsh 5.9 + Powerlevel10k
- Container Runtime: Podman (rootless)
- Bar: DMS (QuickShell-based)
- Editor: Neovim 0.11.6

**Boot Performance:**
- Total: ~20s (firmware 9s + kernel 6s + userspace 3.5s)
- Terminal startup: <100ms (with operator framework)
- Memory at idle: ~4GB / 32GB (13%)

## Setup Instructions

### Clone the Repository
```bash
git clone https://github.com/ForeverLX/offsec-workstation.git
cd offsec-workstation
```

### Installation
**Prerequisites:**
- Arch Linux installed
- Base system configured (user, network, AUR helper)

**Quick Start:**
```bash
# 1. Install core packages (review first!)
# See manifests/host-packages.txt for full list

# 2. Deploy dotfiles
cp -r dotfiles/niri ~/.config/
cp -r dotfiles/ghostty ~/.config/
# ... (see docs/INSTALL.md for full steps)

# 3. Build container profiles
./modules/container/scripts/container.sh build-all

# 4. Initialize operator terminal
# Automatic on first shell launch
```

**Full documentation**: See [docs/INSTALL.md](docs/INSTALL.md)

### Container Profiles
Build and run container profiles for isolated offensive workflows:

```bash
# Build all container profiles
./modules/container/scripts/container.sh build-all

# Run a specific profile
./modules/container/scripts/container.sh run [toolbox|ad|re|web]

# See docs/CONTAINER-QUICKREF.md for full usage
```

## Key Features

- **Arch Linux**: Rolling release, full control, minimal bloat
- **Niri Compositor**: Scrolling tiling, per-monitor workspaces, Wayland-native
- **Operator Terminal Framework**: Contextual awareness (VPN, engagement, git, network)
- **Container Profiles**: Rootless Podman profiles for ad, re, and web workflows
- **Offensive Security Toolchain**: Curated tools for pentesting, CTFs, vulnerability research
- **Automated Audits**: Package, security, and performance baselines
- **Custom Dotfiles**: Streamlined configs for efficiency and aesthetics
- **MITRE Logging**: Built-in ATT&CK technique tracking
- **Multi-monitor**: Mixed DPI support (4K + 1080p tested)

## Offensive Security Tools Inventory

This repository includes a documented offensive security tools inventory to clearly show the core tools I use (with invocation methods and purpose) in offensive security workflows and labs — useful for recruiters and technical reviewers.

See [docs/tools-inventory.md](docs/tools-inventory.md)

## Purpose of this Project

The goal of this project is to create a reproducible, secure, and performant workstation for offensive security tasks. It is built to be:

- **Modular**: Easily extensible with new tools and configurations as needed
- **Minimal**: Avoiding unnecessary bloat and focusing only on what is required
- **Secure**: Firewall hardening, SSH lockdown, rootless containers, OPSEC-aware
- **Contextual**: Operator terminal provides instant awareness of operational state
- **Documented**: Well-documented configs, audits, and methodologies for transparency

This repository evolves continuously as I refine workflows and learn new techniques in offensive security.

## Repo Layout

```
offsec-workstation/
├── docs/                     # Documentation, audits, guides
├── dotfiles/
│   ├── niri/                 # Niri compositor config (modular)
│   ├── ghostty/              # Terminal config
│   ├── zsh/                  # Shell configuration
│   └── ...
├── manifests/                # Package manifests (host + containers)
├── modules/
│   └── container/            # Container profiles (toolbox, ad, re, web)
├── scripts/
│   ├── audit/                # Security & package audits
│   ├── benchmark/            # Performance baselines
│   ├── engagement/           # Engagement initialization
│   └── ...
└── README.md                 # This file
```

## System Snapshot History

- **Latest**: docs/system-snapshot.md (rolling 3-month retention on GitHub)

## Performance & Network Optimization

See docs/performance-optimization.md for safe, incremental tuning steps and network stability notes.

## Labs & Practice

Lab writeups and challenge artifacts live in the [security portfolio repository](https://github.com/ForeverLX/security-portfolio).

**Note**: Sensitive configurations and live service details are intentionally excluded from public documentation to respect OPSEC.

## Screenshots & Video

Coming soon: workstation screenshots and a short walkthrough video demonstrating:
- Operator terminal framework in action
- Niri scrolling layout and overview mode
- Container profile workflows
- Multi-monitor setup
- Theme switching (OPSEC dark/light modes)

---

## Changelog

### v0.5.0 - Operator Terminal Framework + Niri Migration (2026-03-XX)
- ✨ NEW: Operator terminal framework with VPN/engagement/git/network awareness
- ✨ NEW: MITRE ATT&CK logging system (`mitre log`)
- ✨ NEW: Engagement initialization script (`new-engagement`)
- 🔄 CHANGED: Migrated from Sway to Niri compositor
- 🔄 CHANGED: Integrated DMS (Dank Material Shell) for bar/launcher
- 🔄 CHANGED: Hybrid keybind system (custom + DMS features)
- ⚡ IMPROVED: Terminal startup <100ms (from ~300ms)
- ⚡ IMPROVED: Multi-monitor support with mixed DPI
- 🎨 IMPROVED: Professional window transparency rules
- 📝 DOCS: Complete Niri migration guide
- 📝 DOCS: Operator terminal framework documentation

### v0.4.0 - Container Profile Architecture (2026-02-XX)
- ✨ NEW: Rootless Podman container profiles (toolbox, ad, re, web)
- 📦 Package audit and cleanup (920 packages)
- 🔒 Security hardening (firewall, SSH, shell history)
- 📊 Performance baselines established
- 📁 Directory reorganization (engage/, lab/, loot/)

### v0.3.0 and earlier
- See [CHANGELOG.md](CHANGELOG.md) for full history

---

**Latest Release**: [v0.5.0 - Operator Terminal Framework](https://github.com/ForeverLX/offsec-workstation/releases/tag/v0.5.0)

**Author**: ForeverLX (Darrius Grate)
**License**: MIT
**Contact**: [GitHub Profile](https://github.com/ForeverLX)
