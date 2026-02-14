# Container Build & Run Quick Reference

## Initial Setup

1. **Build toolbox first** (base layer for all profiles):
   ```bash
   ./modules/container/scripts/container.sh build toolbox
   ```

2. **Build all profiles** (recommended):
   ```bash
   ./modules/container/scripts/container.sh build-all
   ```

## Running Containers

Each profile automatically mounts your workspace directories:
- ~/engage
- ~/loot
- ~/notes
- ~/exploitdev
- ~/projects

```bash
# Run AD engagement container
./modules/container/scripts/container.sh run ad

# Run reverse engineering container
./modules/container/scripts/container.sh run re

# Run web recon container
./modules/container/scripts/container.sh run web
```

## Rebuilding After Changes

```bash
# Rebuild single profile (e.g., after updating ad-packages.txt)
./modules/container/scripts/container.sh build ad

# Rebuild all profiles (after toolbox changes)
./modules/container/scripts/container.sh build-all
```

## Maintenance

```bash
# List all built images
./modules/container/scripts/container.sh list

# Clean up dangling images
./modules/container/scripts/container.sh clean

# Export for air-gapped engagement
./modules/container/scripts/container.sh export ad
# Produces: offsec-ad-0.1.0-20260214.tar

# Import on target system
./modules/container/scripts/container.sh import offsec-ad-0.1.0-20260214.tar
```

## Version Tagging

Each build creates two tags:
- **Version tag**: `localhost/offsec-ad:0.1.0` (stable reference)
- **Date tag**: `localhost/offsec-ad:20260214` (point-in-time snapshot)

To update version, edit `VERSION="0.1.0"` in container.sh

## Troubleshooting

### Build fails with "cannot perform this operation unless you are root"
- Ensure Containerfile has `USER root` before `RUN pacman` commands
- Check that toolbox builds successfully first

### Container can't find base image
- Verify `FROM containers-storage:localhost/offsec-toolbox:0.1.0`
- Rebuild toolbox if needed

### Python packages fail to install
- Check that `python` and `python-pip` are in the profile's packages.txt
- Use `pip install --break-system-packages` flag in Containerfile

## Architecture

```
toolbox (base)
├── ad-profile    (Impacket, Kerberos, LDAP)
├── re-profile    (radare2, GDB, pwntools)
└── web-profile   (nmap, httpx, naabu)
```

All profiles inherit from toolbox and add specialized tooling.
