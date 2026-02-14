# Container Profile Architecture

## Overview

Rootless Podman container profiles for offensive security workflows. Each profile is:
- **Reproducible**: Built from version-controlled manifests
- **Minimal**: Only includes necessary tools for its purpose
- **Modular**: Profiles are independent and composable
- **Local-first**: No external registries required

## Profile Structure

```
toolbox (base)
├── ad-profile    → Active Directory engagement tooling
├── re-profile    → Reverse engineering & vuln research
└── web-profile   → Web recon & enumeration
```

### toolbox (Base Layer)
- Minimal Arch Linux with core CLI utilities
- Python 3.14 runtime for all profiles
- Network utilities, git, tmux, neovim
- Size: ~1.1 GB

### ad-profile
- **Purpose**: Enterprise AD engagements, Kerberos abuse, LDAP interrogation
- **Key Tools**: Impacket, Kerberos (krb5), Samba, LDAP utils
- **Size**: ~1.3 GB
- **Use case**: Domain enumeration, credential attacks, lateral movement

### re-profile  
- **Purpose**: Binary analysis, vulnerability research, exploit development
- **Key Tools**: radare2, GDB, pwntools, ROPgadget, capstone, unicorn
- **Size**: ~1.8 GB
- **Use case**: Reverse engineering, ROP chain building, binary exploitation

### web-profile
- **Purpose**: Web reconnaissance, service enumeration, HTTP tooling
- **Key Tools**: nmap, masscan, gobuster, httpx, requests
- **Size**: ~1.1 GB
- **Use case**: External attack surface mapping, web app discovery

## Directory Contract

Containers automatically mount these host directories:
- `~/engage` - Active engagement data
- `~/loot` - Captured credentials, files
- `~/notes` - Documentation, observations
- `~/exploitdev` - Exploit code, payloads
- `~/projects` - Long-term projects

All mounts use `:Z` (SELinux relabeling) for rootless security.

## Build System

### Quick Start
```bash
# Build all profiles
./modules/container/scripts/container.sh build-all

# Build individual profile
./modules/container/scripts/container.sh build ad

# Run profile
./modules/container/scripts/container.sh run ad
```

### Version Management
Each build creates two tags:
- `localhost/offsec-ad:0.1.0` - Stable version reference
- `localhost/offsec-ad:20260214` - Date-stamped snapshot

Update `VERSION` in `container.sh` to bump versions.

### Air-Gapped Workflows
```bash
# Export for offline use
./modules/container/scripts/container.sh export ad
# Produces: offsec-ad-0.1.0-20260214.tar

# Import on target
./modules/container/scripts/container.sh import offsec-ad-0.1.0-20260214.tar
```

## Design Principles

### No Kitchen Sink
Each profile contains only tools relevant to its purpose. Avoid tool hoarding.

### Explicit Mounts Only
Never mount `$HOME` or `/`. Containers see only declared directories.

### Rootless by Default
All profiles run as non-root `operator` user with `--userns=keep-id`.

### Official Packages Only
Prefer official Arch repos over AUR. Document manual install for AUR tools.

## Package Manifest Format

Manifests in `manifests/*.txt`:
- Comments start with `#` on their own line
- No inline comments (breaks grep filtering)
- One package per line
- Blank lines ignored

Example:
```
# Kerberos tooling
krb5

# LDAP utilities
openldap
```

## Known Issues & Workarounds

### libgcc Conflicts
Arch base images have `gcc-libs` → `libgcc` transition issues. Fixed by:
1. Full system upgrade in toolbox: `pacman -Syu --overwrite='*'`
2. Use `--overwrite='*'` in derived containers

### Python 3.14 Compatibility
Some packages (e.g., `ropper`) have deprecated `ast.Str` usage. Use maintained alternatives:
- ✅ ROPgadget (instead of ropper)
- ✅ Modern Impacket builds

### AUR Tools
Tools like `ffuf` and `naabu` are AUR-only. Use official alternatives:
- `ffuf` → `gobuster` (or manual install)
- `naabu` → `masscan` + `nmap`

## See Also
- [CONTAINER-QUICKREF.md](CONTAINER-QUICKREF.md) - Command reference
- [ROADMAP.md](ROADMAP.md) - Development phases
- [DECISIONS.md](DECISIONS.md) - Architectural choices
