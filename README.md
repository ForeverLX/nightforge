# NightForge

**Azrael Security — Operator Workstation**

Built and operated by [ForeverLX](https://github.com/ForeverLX) | Azrael Security™

Part of the [Veil](https://github.com/ForeverLX/veil) infrastructure project.

> NightForge is the primary operator workstation for Azrael Security. It is a daily-use, production-grade offensive security environment built on Arch Linux with the Niri compositor. The emphasis is on reproducibility, operational awareness, OPSEC-safe workflows, and long-term maintainability — not disposable lab setups.

---

## System

| Component | Detail |
|---|---|
| **CPU** | Intel i3-10105F (4c/8t @ 4.40 GHz) |
| **RAM** | 32GB |
| **GPU** | NVIDIA GTX 1650 |
| **Storage** | 512GB NVMe (/) + 512GB NVMe (/home) |
| **OS** | Arch Linux (rolling) |
| **Compositor** | Niri 25.x (Wayland, scrolling tiling) |
| **Terminal** | Ghostty |
| **Shell** | Zsh + Starship |
| **Editor** | Neovim (LSP configured) |
| **Container runtime** | Podman (rootless) |
| **WireGuard IP** | `10.0.0.3` (Veil mesh) |

---

## Operator Terminal Framework (v0.5.0)

Contextual awareness system that surfaces operational state on every terminal launch. Startup time: <100ms.

**What it shows:**
- VPN status and IP (HTB, TryHackMe, WireGuard mesh)
- Active engagement context (auto-detected from `~/engage/` directories)
- Network awareness (interface, type, local IP)
- Podman container status
- Git context (repo, branch, dirty state)
- System health (packages, disk, memory, uptime)
- MITRE ATT&CK technique log count

**MITRE logging:**
```bash
mitre log T1059.004 "Executed Poseidon implant via bash"
```

See [docs/OPERATOR-TERMINAL.md](docs/OPERATOR-TERMINAL.md) for full documentation.

---

## Container Profiles (v0.4.0)

Rootless Podman profiles for isolated offensive workflows. Each profile is minimal and built from version-controlled manifests.

> **Status:** Manifests and Dockerfiles are present and version controlled. Profiles have not been fully validated end-to-end on the current system state. Treat as in-progress — verify before use in engagements.

| Profile | Purpose | Approx Size |
|---|---|---|
| `toolbox` | Base Arch Linux + Python runtime | ~1.1 GB |
| `ad` | Active Directory engagement tooling | ~1.3 GB |
| `re` | Reverse engineering + vulnerability research | ~1.8 GB |
| `web` | Web recon + enumeration | ~1.1 GB |

```bash
# Build all profiles
./modules/container/scripts/container.sh build-all

# Run a profile (mounts engage/, loot/, notes/, exploitdev/, projects/)
./modules/container/scripts/container.sh run ad

# Export for air-gapped work
./modules/container/scripts/container.sh export ad
```

See [docs/CONTAINER.md](docs/CONTAINER.md) and [docs/CONTAINER-QUICKREF.md](docs/CONTAINER-QUICKREF.md).

---

## Niri Compositor

Wayland compositor with a scrolling tiling layout — windows never resize unexpectedly, scroll horizontally through unlimited workspace width.

**Key integrations:**
- **DMS (Dank Material Shell):** unified bar, launcher, system tray, wallpaper management
- **Vim-style navigation:** `Mod+H/J/K/L` with custom focus-or-spawn scripts
- **Theme switching:** OPSEC dark/light modes, demo mode for client presentations
- **Multi-monitor:** mixed DPI/scaling (tested on dual 1080p)

See [docs/NIRI-MIGRATION.md](docs/NIRI-MIGRATION.md) for migration notes from Sway.

---

## Repository Structure

```
nightforge/
├── README.md
├── install.sh
├── docs/
│   ├── INSTALL.md
│   ├── OPERATOR-TERMINAL.md
│   ├── CONTAINER.md
│   ├── CONTAINER-QUICKREF.md
│   ├── NIRI-MIGRATION.md
│   ├── tools-inventory.md
│   └── system-snapshot.md
├── dotfiles/
│   ├── niri/
│   ├── ghostty/
│   └── zsh/
├── manifests/
│   └── host-packages.txt
├── modules/
│   └── container/
│       └── scripts/
│           └── container.sh
├── profiles/
├── scripts/
│   ├── audit/
│   ├── benchmark/
│   └── engagement/
└── system/
    └── optimizations/
```

---

## Setup

```bash
git clone https://github.com/ForeverLX/nightforge.git
cd nightforge

# Review manifests/host-packages.txt before installing anything
# Full steps: docs/INSTALL.md

# Deploy dotfiles
cp -r dotfiles/niri ~/.config/
cp -r dotfiles/ghostty ~/.config/

# Build container profiles (verify each before use)
./modules/container/scripts/container.sh build-all
```

---

## Changelog

### v0.5.0 — Operator Terminal Framework + Niri Migration
- Operator terminal framework (VPN/engagement/git/network context)
- MITRE ATT&CK logging (`mitre log`)
- Engagement initialization script (`new-engagement`)
- Migrated from Sway to Niri compositor
- Integrated DMS bar/launcher
- Shell prompt: migrated to Starship (zinit retained for plugins only)
- Terminal startup: <100ms

### v0.4.0 — Container Profile Architecture
- Rootless Podman profiles (toolbox, ad, re, web)
- Package audit and cleanup
- Security hardening (firewall, SSH, shell history)
- Performance baselines

---

## Disclaimer

All tooling is for authorized security research and engagement work only. Sensitive configurations and live operational details are intentionally excluded from this repository.

---

**Author:** Darrius Grate (ForeverLX) | Azrael Security™
**License:** MIT
