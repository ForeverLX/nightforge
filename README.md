# Arch Sway Offensive Security Workstation

## Executive Summary
This repository documents the audit, cleanup, hardening, and reorganization of my daily-use offensive security workstation running Arch Linux and Sway. The work focuses on reducing attack surface, improving operational reliability, and establishing repeatable, OPSEC-safe workflows suitable for real offensive security research and lab work.

Rather than treating the workstation as a disposable lab, this project approaches it as a long-lived system: changes are measured, documented, validated, and revisited over time. The result is a stable, secure, and maintainable environment that supports exploit development, reverse engineering, and assessment-style workflows without sacrificing usability.

## 🐳 Container Profiles (NEW - v0.4.0)

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

## Why This Matters
Offensive security tooling is often demonstrated in disposable or undocumented environments. In practice, professional offensive work depends on systems that are stable, predictable, and trustworthy over time.

This project matters because it treats the workstation itself as part of the attack surface and the workflow:

- **Reduced ambient risk**: Fewer unnecessary packages, services, and network features means fewer unintended behaviors on hostile networks.
- **Operational clarity**: A standardized directory layout, clear PATH usage, and documented tool locations reduce mistakes and friction during real work.
- **Reproducibility**: Audit-first changes and automated health checks make it possible to reason about system state instead of guessing.
- **OPSEC awareness**: Verification steps are documented without publishing sensitive system details or raw listener data.
- **Long-term maintainability**: The system is designed to evolve safely, not require periodic rebuilds to "reset" problems.

## Who This Is For
This repository is written to be useful to a few different audiences:

**Recruiters / Hiring Managers:**  
A quick, concrete example of how I approach system ownership: audit-first changes, risk reduction, clear documentation, and repeatable workflows. Start with the Executive Summary, Why This Matters, and the Container Profiles section.

**Offensive Security Practitioners / Red Teamers:**  
Practical workstation practices that reduce friction during labs and assessment-style workflows (tool organization, OPSEC-safe validation, stable paths, repeatable checks) without breaking daily usability.

**Linux / Infrastructure Engineers:**  
A documented approach to maintaining a long-lived workstation: package and service minimization, permissions hygiene, boot baseline measurement, and lightweight automation for ongoing system health.

If you're new to Arch or hardening, you can treat this as a reference for how to think about changes: measure first, change deliberately, and validate after.

## Lab Methodology (Built Environments)
I design and maintain small, isolated lab environments (e.g., Active Directory, Linux, and mixed network setups) to practice realistic offensive workflows against systems I configured myself. Each lab starts from a known baseline, stays within defined scope, and emphasizes minimal validation, evidence capture, and clear remediation-focused reporting.

The focus is not on "winning" challenges, but on repeatable methodology: understanding system behavior, validating impact safely, and documenting findings in a way that would hold up in a real assessment or internal review.

## System Snapshot History
- **Latest**: docs/system-snapshot.md (rolling 3-month retention on GitHub)

## Performance & Network Optimization
See docs/performance-optimization.md for safe, incremental tuning steps and network stability notes.

## Overview
This repository contains the configuration, tools, and resources for setting up a high-performance, secure, and productive offensive security workstation. Built on Arch Linux with the Sway window manager, it is designed to be the ultimate environment for penetration testing, vulnerability research, and offensive security practices. This repository serves as both a personal reference and a public showcase of the setup that fuels my journey as a self-taught penetration tester.

The workstation focuses on minimalism, performance, and security, with tools tailored for red teaming, penetration testing, and security research.

## Setup Instructions

### Clone the Repository
To begin using this setup, clone the repository to your local machine:

```bash
git clone https://github.com/ForeverLX/offsec-workstation.git
cd offsec-workstation
```

### Installation
After cloning, review the scripts directory to install the necessary components and tools for the offensive security workstation:

```bash
cd offsec-workstation
# Review scripts/ for manual setup steps
```

**Note**: Setup scripts are being finalized; use the scripts directory as reference for manual steps.

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
- **Arch Linux**: The base operating system, known for its flexibility, speed, and full control over installed components.
- **Sway**: A Wayland compositor that replaces X11 with a more modern and lightweight display server.
- **Container Profiles**: Rootless Podman profiles for ad, re, and web workflows with explicit directory mounts.
- **Offensive Security Toolchain**: A curated collection of open-source tools for penetration testing, CTFs, and vulnerability research.
- **Automated Audits**: Regular audits for installed packages, services, and disk usage to ensure an optimized and secure environment.
- **Custom Dotfiles**: Configurations for a streamlined, efficient development and security testing environment.

## Offensive Security Tools Inventory
This repository includes a documented offensive security tools inventory to clearly show the core tools I use (with invocation methods and purpose) in offensive security workflows and labs — useful for recruiters and technical reviewers.

See [docs/tools-inventory.md](docs/tools-inventory.md)

## Purpose of this Project
The goal of this project is to create a reproducible, secure, and performant workstation for offensive security tasks. It is built to be:

- **Modular**: Easily extensible with new tools and configurations as needed.
- **Minimal**: Avoiding unnecessary bloat and focusing only on what is required for offensive security.
- **Secure**: Prioritizing privacy, data integrity, and minimal attack surface.
- **Documented**: Well-documented, including detailed explanations of configurations and methodologies, to facilitate understanding and onboarding for peers and potential employers.

This repository will evolve as I continue learning and refining my skills in offensive security, with plans for additional sections such as labs, training, and research findings.

## Repo Layout
```
offsec-workstation/
├── docs/              # Documentation, snapshots, audits, tool inventory
├── dotfiles/          # Configuration files for sway, tmux, shell, etc.
├── manifests/         # Package manifests for host and containers
├── modules/
│   └── container/     # Container profiles (toolbox, ad, re, web)
├── profiles/          # Profile-specific configurations
├── scripts/           # Helper scripts and automation
└── README.md          # This file
```

## Labs & Practice
Lab writeups and challenge artifacts live in the [security portfolio repository](https://github.com/ForeverLX/security-portfolio).

**Note**: Sensitive configurations and live service details are intentionally excluded from public documentation to respect OPSEC.

## Screenshots & Video
Coming soon: workstation screenshots and a short walkthrough video.

---

**Latest Release**: [v0.4.0 - Container Profile Architecture](https://github.com/ForeverLX/offsec-workstation/releases/tag/v0.4.0)
