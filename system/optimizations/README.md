# System Optimizations

**Status:** Active  
**Applied:** Phase 6.2  
**Last Updated:** 2026-02-25

---

## Overview

Centralized management of all system performance optimizations.

**Performance Improvements:**
- CPU: 5.25x faster (800MHz → 4200MHz)
- Network: BBR congestion control, increased buffers
- Memory: Optimized for 32GB RAM
- Storage: NVMe performance mode
- Boot: ~10s boot time

---

## Active Optimizations

| Module | Files | Status | Impact |
|--------|-------|--------|--------|
| CPU | cpu-performance.service | ✅ Active | Performance governor |
| Network | sysctl, udev | ✅ Active | BBR, large buffers, RPS |
| Memory | sysctl, tmpfiles | ✅ Active | Low swap, hugepages |
| Storage | udev | ✅ Active | NVMe power management |
| Boot | systemd | ✅ Active | Disabled slow services |

---

## Quick Commands

```bash
# Apply all optimizations (on fresh system)
./apply-all.sh

# Apply individual module
./cpu/install.sh
./network/install.sh
# etc...

# Check what's installed
../services/list-custom.sh

# Backup current state
../services/backup-configs.sh
```

---

## Module Documentation

See each subdirectory for details:
- `cpu/README.md` - CPU governor configuration
- `network/README.md` - Network tuning details
- `memory/README.md` - Memory management settings
- `storage/README.md` - I/O scheduler optimization
- `boot/README.md` - Boot time improvements

---

## Installation

**From this repo:**
```bash
cd system/optimizations
./apply-all.sh
sudo reboot
```

**Verify after reboot:**
```bash
perf-status
```

---

## Rollback

Each module creates `.backup` files before installation.

To rollback everything:
```bash
sudo systemctl disable cpu-performance.service
sudo rm /etc/sysctl.d/99-*-performance.conf
sudo rm /etc/udev/rules.d/99-*.rules
sudo rm /etc/tmpfiles.d/hugepages.conf
sudo systemctl unmask man-db.service plocate-updatedb.service
sudo sysctl --system
```

Or restore from backups:
```bash
sudo cp /etc/systemd/system/cpu-performance.service.backup \
    /etc/systemd/system/cpu-performance.service
# etc...
```

---

## Testing Performance

```bash
# CPU frequency
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

# Network settings
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max

# Memory settings
sysctl vm.swappiness
cat /sys/kernel/mm/transparent_hugepage/enabled

# I/O scheduler
cat /sys/block/nvme0n1/queue/scheduler

# Boot time
systemd-analyze
```

---

**Performance validated:** Phase 6.2
