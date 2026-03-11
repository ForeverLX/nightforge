# Operator Terminal Framework

## Overview
Context-aware terminal startup system providing instant operational intelligence.

**Startup Time:** <100ms (14 modules)

## Architecture
```
Terminal Launch → Zsh → P10k Instant Prompt → operator-init.sh
    ↓
Random Banner → Fastfetch → 14 Modules → Ready
```

## Modules (14 total)

### Detection Modules
1. **vpn-status.sh** - Detects VPN (HTB, THM, Proxmox via tun/tap)
2. **network-context.sh** - Classifies network (Local Lab, Internal, Public)
3. **network-speed.sh** - Shows interface speed (ethtool)
4. **git-context.sh** - Repository, branch, uncommitted changes
5. **engagement-context.sh** - Engagement directory detection
6. **target-tracking.sh** - Shows current target from `.target` file

### Status Modules
7. **container-status.sh** - Podman container count
8. **container-health.sh** - Enhanced container details (names, status)
9. **tmux-sessions.sh** - Tmux session count (active/total)
10. **disk-warning.sh** - Alerts if disk >80%
11. **lab-status.sh** - Proxmox/Ludus detection (future)
12. **workspace-mode.sh** - Exploit dev / engagement detection
13. **mitre-logger.sh** - Recent MITRE techniques
14. **custom-banner.sh** - Contextual tips

## Usage

### MITRE Logging
```bash
# Log technique
mitre log T1059.001 "PowerShell reverse shell via SCF"

# View log
mitre view
```

### Engagement Workflow
```bash
# Initialize engagement
new-engagement acme-corp 192.168.1.0/24

# Terminal detects automatically:
[⚡] ENGAGEMENT: acme-corp (active)
[→] Target: 192.168.1.0/24
```

## Configuration

**Location:** `~/.config/operator-terminal/`

**Adding Custom Modules:**
```bash
# Create module
cat > ~/.config/operator-terminal/modules/custom.sh << 'SCRIPT'
#!/bin/bash
# Your custom detection logic
echo -e "\033[0;32m[✓] Custom:\033[0m Info here"
SCRIPT

chmod +x ~/.config/operator-terminal/modules/custom.sh

# Auto-loads on next shell launch
```

## Performance

**Benchmark:**
```bash
time (source ~/.config/operator-terminal/operator-init.sh)

# Results:
# real: 0m0.087s
# - Fastfetch: 45ms
# - 14 modules: 32ms (2.3ms per module)
# - Banner: 10ms
```

## Troubleshooting

**Module not running:**
```bash
# Check permissions
ls -la ~/.config/operator-terminal/modules/

# Make executable
chmod +x ~/.config/operator-terminal/modules/*.sh

# Test individual module
~/.config/operator-terminal/modules/vpn-status.sh
```

**Slow startup:**
```bash
# Profile execution
bash -x ~/.config/operator-terminal/operator-init.sh

# Disable slow modules (comment out in operator-init.sh)
```
