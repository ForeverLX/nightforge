# Host Maintenance System

Automated host package audit, cleanup, and monitoring for offsec-workstation.

## Features

### Automated Checks
- ✅ **Orphaned packages** - Detect and remove unused dependencies
- ✅ **Package cache** - Clean old package files (keep last 2 versions)
- ✅ **Old packages** - Flag packages over 1 year old
- ✅ **System updates** - Check for available updates
- ✅ **Security audit** - CVE scanning with arch-audit
- ✅ **Container health** - Verify profiles and clean dangling images

### Modes
- **Interactive** - Prompts before each action (default)
- **Non-interactive** - Automated mode for cron/systemd
- **Dry-run** - Show what would be done without changes

### Reporting
- JSON snapshots of system state
- Markdown maintenance reports
- Structured logging to `/var/log/offsec-workstation/`

---

## Installation

```bash
cd ~/Github/offsec-workstation/scripts/maintenance
sudo ./install-maintenance.sh
```

This installs:
- `/usr/local/bin/offsec-maintenance` - Main script
- `/etc/systemd/system/offsec-maintenance.service` - Systemd service
- `/etc/systemd/system/offsec-maintenance.timer` - Weekly timer
- `/var/log/offsec-workstation/` - Log directory

---

## Usage

### Manual Execution

**Interactive mode** (default):
```bash
offsec-maintenance
```

Prompts before each action:
```
Found 12 orphaned packages:
python-old-dep-1
python-old-dep-2
...
Remove orphaned packages? [y/N]
```

**Non-interactive mode** (automated):
```bash
sudo offsec-maintenance --non-interactive
```

No prompts - runs all checks and performs safe actions automatically.

**Dry-run mode** (test):
```bash
offsec-maintenance --dry-run
```

Shows what would be done without making changes.

---

### Automated Execution

**Weekly timer** (installed by default):
- Runs every Sunday at 3 AM
- Random 0-30 minute delay
- Persistent (runs on boot if missed)

**Check timer status**:
```bash
systemctl status offsec-maintenance.timer
```

**View next run time**:
```bash
systemctl list-timers offsec-maintenance.timer
```

**Run now** (manual trigger):
```bash
sudo systemctl start offsec-maintenance.service
```

**View logs**:
```bash
# Systemd journal
journalctl -u offsec-maintenance.service

# Log file
tail -f /var/log/offsec-workstation/maintenance.log

# Recent runs
journalctl -u offsec-maintenance.service --since "1 week ago"
```

---

## Configuration

### Environment Variables

**Set in service file** (`/etc/systemd/system/offsec-maintenance.service`):

```ini
[Service]
Environment="INTERACTIVE=false"
Environment="LOG_DIR=/var/log/offsec-workstation"
```

**Or set when running manually**:
```bash
INTERACTIVE=false DRY_RUN=true offsec-maintenance
```

### Thresholds

Edit `/usr/local/bin/offsec-maintenance`:

```bash
# Configuration
ORPHAN_THRESHOLD=10              # Remove if more than 10 orphans
CACHE_SIZE_THRESHOLD_GB=5        # Clean if cache > 5 GB
PACKAGE_AGE_DAYS=30              # Flag packages older than this
```

---

## Outputs

### Snapshots
`~/.local/share/offsec-workstation/reports/snapshot-YYYYMMDD-HHMMSS.json`

```json
{
  "timestamp": "2026-02-20T22:53:00-08:00",
  "packages": {
    "total": 762,
    "explicit": 138,
    "orphans": 0
  },
  "disk": {
    "packages_gb": 6.49,
    "cache_gb": 4.20
  },
  "containers": {
    "images": 8,
    "running": 0
  }
}
```

### Reports
`~/.local/share/offsec-workstation/reports/report-YYYYMMDD-HHMMSS.md`

Markdown summary with:
- System state snapshot
- Actions taken
- Warnings and recommendations

### Logs
`/var/log/offsec-workstation/maintenance.log`

Timestamped entries:
```
2026-02-20 22:53:15 [INFO] Checking for orphaned packages...
2026-02-20 22:53:16 [SUCCESS] No orphaned packages found
2026-02-20 22:53:16 [INFO] Checking package cache...
2026-02-20 22:53:17 [WARN] Cache exceeds 5 GB threshold
```

---

## Actions Performed

### Safe Actions (Non-Interactive)
These run automatically in non-interactive mode:

- ✅ Create system snapshot
- ✅ Check and log orphans (removes if > threshold)
- ✅ Check and log cache size (cleans if > threshold)
- ✅ Flag old packages (no removal)
- ✅ Check for updates (no installation)
- ✅ Run security audit
- ✅ Check container health
- ✅ Generate report

### Manual Actions (Interactive Only)
These require confirmation:

- System updates (`pacman -Syu`)
- Removing specific packages
- Aggressive cache cleaning

---

## Customization

### Change Schedule

Edit `/etc/systemd/system/offsec-maintenance.timer`:

```ini
[Timer]
# Daily at 3 AM
OnCalendar=*-*-* 03:00:00

# Or monthly on the 1st
OnCalendar=*-*-01 03:00:00

# Or every 6 hours
OnCalendar=*-*-* 00/6:00:00
```

Then reload:
```bash
sudo systemctl daemon-reload
sudo systemctl restart offsec-maintenance.timer
```

### Add Custom Checks

Edit `/usr/local/bin/offsec-maintenance` and add function:

```bash
check_custom() {
    log_info "Running custom check..."
    
    # Your check here
    
    if [[ condition ]]; then
        log_warn "Custom warning"
    else
        log_success "Custom check passed"
    fi
}
```

Call it in `main()`:
```bash
check_custom
echo
```

---

## Troubleshooting

### Timer not running

```bash
# Check timer is enabled
systemctl is-enabled offsec-maintenance.timer

# Enable if needed
sudo systemctl enable offsec-maintenance.timer
sudo systemctl start offsec-maintenance.timer

# Check logs
journalctl -u offsec-maintenance.timer
```

### Permission errors

```bash
# Fix log directory permissions
sudo chown root:root /var/log/offsec-workstation
sudo chmod 755 /var/log/offsec-workstation

# Or run with sudo
sudo offsec-maintenance
```

### Script not found

```bash
# Verify installation
ls -la /usr/local/bin/offsec-maintenance

# Reinstall if needed
cd ~/Github/offsec-workstation/scripts/maintenance
sudo ./install-maintenance.sh
```

---

## Uninstallation

```bash
# Stop and disable timer
sudo systemctl stop offsec-maintenance.timer
sudo systemctl disable offsec-maintenance.timer

# Remove files
sudo rm /usr/local/bin/offsec-maintenance
sudo rm /etc/systemd/system/offsec-maintenance.service
sudo rm /etc/systemd/system/offsec-maintenance.timer

# Remove logs (optional)
sudo rm -rf /var/log/offsec-workstation

# Reload systemd
sudo systemctl daemon-reload
```

---

## Integration with Container Profiles

The maintenance system checks for:
- Missing container profiles (toolbox, ad, re, web)
- Dangling container images
- Container build issues

Automatically reminds you to rebuild if profiles are missing:
```
Missing container profiles: re
Run: ./modules/container/scripts/container.sh build re
```

---

## Best Practices

1. **Run manually first** - Test with `--dry-run` before enabling timer
2. **Review logs weekly** - Check `/var/log/offsec-workstation/maintenance.log`
3. **Keep reports** - Snapshots useful for tracking package drift
4. **Adjust thresholds** - Tune based on your usage patterns
5. **Monitor cache** - Clean when needed, but keep recent packages

---

## Related Documentation

- [HOST-AUDIT.md](../../docs/HOST-AUDIT.md) - Initial audit results
- [ROADMAP.md](../../docs/ROADMAP.md) - Project phases
- [WORKFLOWS.md](../../docs/WORKFLOWS.md) - Daily workflows

---

**Version**: 1.0.0  
**Last Updated**: February 20, 2026
