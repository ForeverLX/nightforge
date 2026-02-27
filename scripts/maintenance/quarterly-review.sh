#!/bin/bash
# Quarterly System Review
# Run: March 1, June 1, September 1, December 1
# Purpose: Deep system review, comprehensive security audit

set -e

echo "📊 Quarterly System Review - $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. System Health Overview
echo "[1/9] System health overview..."
UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{print $2}')
MEMORY=$(free -h | awk '/^Mem:/ {print $3 " / " $2}')
echo "  ⏱️  Uptime: $UPTIME"
echo "  📊 Load average:$LOAD"
echo "  💾 Memory usage: $MEMORY"
echo ""
echo "  🔧 Kernel: $(uname -r)"
echo "  🐧 OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"

# 2. Comprehensive Disk Analysis
echo "[2/9] Comprehensive disk analysis..."
echo ""
echo "  💽 Root partition:"
df -h / | tail -n 1 | awk '{print "    Used: "$3" / "$2" ("$5")"}'
echo ""
echo "  🏠 Home partition:"
df -h /home | tail -n 1 | awk '{print "    Used: "$3" / "$2" ("$5")"}'
echo ""
echo "  📁 Top 15 largest directories:"
du -sh ~/* ~/.*/ 2>/dev/null | sort -h | tail -15 | sed 's/^/    /'

# 3. COMPREHENSIVE SECURITY AUDIT
echo "[3/9] 🔒 Comprehensive Security Audit..."
echo ""

# 3a. Failed login attempts
echo "  🚫 Failed login attempts (last 30 days):"
FAILED_SSH=$(sudo journalctl -u sshd --since "30 days ago" 2>/dev/null | grep -c "Failed password" || echo 0)
FAILED_LOGIN=$(sudo journalctl --since "30 days ago" 2>/dev/null | grep -c "authentication failure" || echo 0)
echo "    SSH: $FAILED_SSH"
echo "    Local: $FAILED_LOGIN"

# 3b. Open ports and listening services
echo ""
echo "  🌐 Open ports and listening services:"
sudo ss -tulpn | grep LISTEN | awk '{print "    "$5" → "$7}' | sort -u

# 3c. Running services
echo ""
echo "  ⚙️  System services status:"
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=running --no-legend | wc -l)
FAILED_SERVICES=$(systemctl list-units --type=service --state=failed --no-legend | wc -l)
echo "    Running: $ACTIVE_SERVICES"
echo "    Failed: $FAILED_SERVICES"
if [ "$FAILED_SERVICES" -gt 0 ]; then
    echo ""
    echo "    ⚠️  Failed services:"
    systemctl list-units --type=service --state=failed --no-legend | sed 's/^/      /'
fi

# 3d. Critical package updates
echo ""
echo "  📦 Critical security updates:"
SECURITY_UPDATES=$(pacman -Qu 2>/dev/null | grep -E "linux |systemd |openssl |glibc |openssh |sudo " || echo "")
if [ -n "$SECURITY_UPDATES" ]; then
    echo "    ⚠️  Critical packages need updates:"
    echo "$SECURITY_UPDATES" | sed 's/^/      /'
else
    echo "    ✓ No critical security updates pending"
fi

# 3e. SSH configuration review
echo ""
echo "  🔑 SSH configuration:"
if [ -f /etc/ssh/sshd_config ]; then
    ROOT_LOGIN=$(sudo grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null || echo "not configured")
    PASSWORD_AUTH=$(sudo grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null || echo "not configured")
    echo "    Root login: ${ROOT_LOGIN:-default}"
    echo "    Password auth: ${PASSWORD_AUTH:-default}"
else
    echo "    ✓ SSH not configured (good for desktop)"
fi

# 3f. Firewall status
echo ""
echo "  🛡️  Firewall status:"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | head -1)
    echo "    $UFW_STATUS"
else
    echo "    ⚠️  No firewall configured (consider ufw)"
fi

# 3g. World-writable files check
echo ""
echo "  📝 Security check - world-writable files in home:"
WRITABLE_COUNT=$(find ~ -type f -perm -002 2>/dev/null | wc -l)
if [ "$WRITABLE_COUNT" -gt 0 ]; then
    echo "    ⚠️  Found $WRITABLE_COUNT world-writable files"
    find ~ -type f -perm -002 2>/dev/null | head -5 | sed 's/^/      /'
    [ "$WRITABLE_COUNT" -gt 5 ] && echo "      ... and $((WRITABLE_COUNT - 5)) more"
else
    echo "    ✓ No world-writable files found"
fi

# 4. Container Ecosystem Review
echo "[4/9] Container ecosystem..."
echo "  🐳 Container images:"
podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}" | sed 's/^/    /'
echo ""
echo "  💾 Total container storage:"
podman system df | sed 's/^/    /'

# 5. Package Health
echo "[5/9] Package health check..."
TOTAL_PKG=$(pacman -Q | wc -l)
ORPHANS=$(pacman -Qdtq 2>/dev/null | wc -l)
AUR_PKG=$(pacman -Qm | wc -l)
OUTDATED=$(checkupdates 2>/dev/null | wc -l)
echo "  📦 Total packages: $TOTAL_PKG"
echo "  📦 Orphaned packages: $ORPHANS"
echo "  📦 AUR packages: $AUR_PKG"
echo "  📦 Outdated packages: $OUTDATED"
if [ "$ORPHANS" -gt 0 ]; then
    echo "  ⚠️  Consider removing orphaned packages"
fi

# 6. Backup Verification
echo "[6/9] Backup verification..."
if [ -d ~/Backups ]; then
    BACKUP_SIZE=$(du -sh ~/Backups 2>/dev/null | awk '{print $1}')
    BACKUP_COUNT=$(find ~/Backups -type f 2>/dev/null | wc -l)
    LATEST_BACKUP=$(find ~/Backups -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -1)
    echo "  💾 Backup size: $BACKUP_SIZE"
    echo "  💾 Backup files: $BACKUP_COUNT"
    if [ -n "$LATEST_BACKUP" ]; then
        echo "  💾 Latest backup: $(echo "$LATEST_BACKUP" | awk '{print $1}') - $(echo "$LATEST_BACKUP" | awk '{print $2}' | xargs basename)"
    else
        echo "  ⚠️  No backups found"
    fi
else
    echo "  ⚠️  No backup directory found"
    echo "  💡 Consider creating ~/Backups for config backups"
fi

# 7. Git Repository Status
echo "[7/9] Git repository health..."
if [ -d ~/Github/offsec-workstation ]; then
    cd ~/Github/offsec-workstation
    UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
    BRANCH=$(git branch --show-current 2>/dev/null)
    LAST_COMMIT=$(git log -1 --format="%cr" 2>/dev/null)
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null)
    echo "  📝 Branch: $BRANCH"
    echo "  📝 Total commits: $COMMIT_COUNT"
    echo "  📝 Uncommitted changes: $UNCOMMITTED"
    echo "  📝 Last commit: $LAST_COMMIT"
    if [ "$UNCOMMITTED" -gt 0 ]; then
        echo "  ⚠️  You have uncommitted changes"
    fi
fi

# 8. System Performance Metrics
echo "[8/9] Performance metrics..."
echo "  📈 CPU frequency:"
CPU_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
if [ -n "$CPU_FREQ" ]; then
    echo "    $(($CPU_FREQ / 1000)) MHz ($(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor))"
else
    echo "    Unable to read"
fi
echo "  📈 Memory breakdown:"
free -h | grep -E "^Mem|^Swap" | sed 's/^/    /'

# 9. Long-term trends
echo "[9/9] Long-term trends..."
echo "  📊 Package growth:"
echo "    Current: $TOTAL_PKG packages"
echo "    (Compare to previous quarterly report)"
echo ""
echo "  💽 Disk growth:"
df -h / /home | tail -n +2 | sed 's/^/    /'
echo "    (Compare to previous quarterly report)"

echo ""
echo "✨ Quarterly review complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ACTION ITEMS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Security:"
echo "  [ ] Review failed login attempts"
echo "  [ ] Verify SSH configuration is secure"
echo "  [ ] Check firewall status"
echo "  [ ] Review open ports and services"
echo "  [ ] Update critical packages"
echo ""
echo "Maintenance:"
echo "  [ ] Remove orphaned packages ($ORPHANS found)"
echo "  [ ] Clean up large directories if needed"
echo "  [ ] Review and prune old container images"
echo "  [ ] Update outdated packages ($OUTDATED available)"
echo ""
echo "Backups:"
echo "  [ ] Verify backups are current"
echo "  [ ] Test backup restore process"
echo "  [ ] Archive old engagement data if needed"
echo ""
echo "Development:"
echo "  [ ] Commit pending git changes ($UNCOMMITTED files)"
echo "  [ ] Review project organization"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📅 Next quarterly review: $(date -d "+3 months" "+%B %Y")"
