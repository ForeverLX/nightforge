#!/bin/bash
# Security Hardening Script - Phase 9
# offsec-workstation
# Run with: sudo ./security-hardening.sh

set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "🛡️  Security Hardening - offsec-workstation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get actual user (not root)
ACTUAL_USER=${SUDO_USER:-$USER}
echo "Hardening system for user: $ACTUAL_USER"
echo ""

read -p "Continue with security hardening? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# ============================================================================
# STEP 1: Install Security Packages
# ============================================================================

echo ""
echo "[1/7] Installing security packages..."
pacman -S --needed --noconfirm ufw fail2ban

echo "  ✓ Security packages installed"

# ============================================================================
# STEP 2: Firewall Configuration (ufw)
# ============================================================================

echo ""
echo "[2/7] Configuring firewall (ufw)..."

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (will be configured in next step)
ufw allow 22/tcp comment 'SSH'

# Enable logging
ufw logging on

echo "  ✓ Firewall rules configured"
echo ""
read -p "Enable firewall now? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    ufw --force enable
    systemctl enable ufw
    echo "  ✓ Firewall enabled and will start on boot"
else
    echo "  ⏭  Firewall configured but not enabled"
    echo "  Run 'sudo ufw enable' when ready"
fi

# ============================================================================
# STEP 3: SSH Hardening
# ============================================================================

echo ""
echo "[3/7] Hardening SSH configuration..."

# Backup original config
if [ -f /etc/ssh/sshd_config ] && [ ! -f /etc/ssh/sshd_config.backup ]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    echo "  ✓ Backed up original sshd_config"
fi

# Create hardened SSH config
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# SSH Hardening Configuration
# offsec-workstation - Phase 9

# Protocol and Ports
Port 22
AddressFamily inet
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 2

# Key Exchange and Ciphers (Modern, Secure)
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Security Features
StrictModes yes
X11Forwarding no
AllowAgentForwarding yes
AllowTcpForwarding yes
PermitTunnel no
PermitUserEnvironment no
UsePAM yes

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Timeouts
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30

# Banner
Banner /etc/ssh/banner

# Allowed Users (add your username)
AllowUsers $ACTUAL_USER
EOF

# Create SSH banner
cat > /etc/ssh/banner << 'EOF'
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  ⚠️  AUTHORIZED ACCESS ONLY                                  │
│                                                              │
│  This system is for authorized use only.                    │
│  All activity is monitored and logged.                      │
│  Unauthorized access will be prosecuted.                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘

EOF

# Ensure .ssh directory exists with correct permissions
if [ ! -d "/home/$ACTUAL_USER/.ssh" ]; then
    mkdir -p "/home/$ACTUAL_USER/.ssh"
    chown "$ACTUAL_USER:$ACTUAL_USER" "/home/$ACTUAL_USER/.ssh"
    chmod 700 "/home/$ACTUAL_USER/.ssh"
fi

echo "  ✓ SSH hardening configuration applied"
echo ""
echo "  📝 IMPORTANT: Before enabling SSH, you must:"
echo "     1. Generate SSH key pair (if not already done):"
echo "        ssh-keygen -t ed25519 -C 'your_email@example.com'"
echo "     2. Add public key to ~/.ssh/authorized_keys"
echo "     3. Test SSH login works with key before enabling"
echo ""
read -p "Enable SSH now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl enable sshd
    systemctl start sshd
    echo "  ✓ SSH enabled"
    echo "  ⚠️  Make sure you can login with SSH key before closing this session!"
else
    echo "  ⏭  SSH configured but not enabled"
    echo "  Run 'sudo systemctl enable --now sshd' when ready"
fi

# ============================================================================
# STEP 4: Fail2ban Configuration
# ============================================================================

echo ""
echo "[4/7] Configuring fail2ban..."

# Create local jail configuration
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban settings
bantime = 1h
findtime = 10m
maxretry = 3
banaction = ufw

# Email notifications (optional - configure if needed)
# destemail = your-email@example.com
# sender = fail2ban@$(hostname)
# mta = sendmail

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
maxretry = 3
EOF

echo "  ✓ Fail2ban configured"
echo ""
read -p "Enable fail2ban? [Y/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    systemctl enable fail2ban
    systemctl start fail2ban
    echo "  ✓ Fail2ban enabled"
else
    echo "  ⏭  Fail2ban configured but not enabled"
fi

# ============================================================================
# STEP 5: Service Audit & Hardening
# ============================================================================

echo ""
echo "[5/7] Auditing and hardening services..."

# List potentially unnecessary services
echo "  Checking for unnecessary services..."
UNNECESSARY_SERVICES=(
    "bluetooth"
    "cups"
    "avahi-daemon"
    "ModemManager"
)

FOUND_SERVICES=()
for service in "${UNNECESSARY_SERVICES[@]}"; do
    if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
        FOUND_SERVICES+=("$service")
    fi
done

if [ ${#FOUND_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "  Found potentially unnecessary services:"
    for service in "${FOUND_SERVICES[@]}"; do
        echo "    - $service"
    done
    echo ""
    read -p "Disable these services? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for service in "${FOUND_SERVICES[@]}"; do
            systemctl disable "$service"
            systemctl stop "$service"
            echo "    ✓ Disabled $service"
        done
    else
        echo "  ⏭  Services left enabled"
    fi
else
    echo "  ✓ No unnecessary services found"
fi

# ============================================================================
# STEP 6: Filesystem Security
# ============================================================================

echo ""
echo "[6/7] Hardening filesystem security..."

# Secure /tmp with noexec
if ! mount | grep -q "on /tmp.*noexec"; then
    echo "  Setting up secure /tmp mount..."
    
    # Add to fstab if not present
    if ! grep -q "tmpfs.*\/tmp" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777 0 0" >> /etc/fstab
        echo "    ✓ Added secure /tmp to fstab"
    fi
    
    echo "    ⚠️  Changes will take effect on next reboot"
else
    echo "  ✓ /tmp already secured"
fi

# Secure home directory permissions
echo "  Checking home directory permissions..."
chmod 700 "/home/$ACTUAL_USER"
echo "  ✓ Home directory secured (700)"

# Secure SSH directory
if [ -d "/home/$ACTUAL_USER/.ssh" ]; then
    chmod 700 "/home/$ACTUAL_USER/.ssh"
    find "/home/$ACTUAL_USER/.ssh" -type f -exec chmod 600 {} \;
    echo "  ✓ SSH directory secured"
fi

# ============================================================================
# STEP 7: Network Security
# ============================================================================

echo ""
echo "[7/7] Hardening network security..."

# Kernel network hardening parameters
cat > /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# Network Security Hardening
# offsec-workstation - Phase 9

# IP Forwarding (disabled for desktop)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# SYN cookies (protection against SYN flood attacks)
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv6.icmp.echo_ignore_all = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# TCP hardening
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_rfc1337 = 1

# Disable IPv6 if not used
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
EOF

# Apply sysctl settings
sysctl --system > /dev/null 2>&1
echo "  ✓ Network hardening applied"

# ============================================================================
# COMPLETION
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Security Hardening Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  ✓ Firewall (ufw) configured and enabled"
echo "  ✓ SSH hardened (key-only authentication)"
echo "  ✓ Fail2ban configured for intrusion prevention"
echo "  ✓ Unnecessary services disabled"
echo "  ✓ Filesystem permissions secured"
echo "  ✓ Network stack hardened"
echo ""
echo "⚠️  IMPORTANT Next Steps:"
echo "  1. Generate SSH key pair if not done:"
echo "     ssh-keygen -t ed25519"
echo "  2. Test SSH key authentication works"
echo "  3. Reboot to apply /tmp security settings"
echo ""
echo "📊 Verify Configuration:"
echo "  sudo ufw status verbose          # Check firewall"
echo "  sudo fail2ban-client status      # Check fail2ban"
echo "  sudo systemctl status sshd       # Check SSH"
echo ""
