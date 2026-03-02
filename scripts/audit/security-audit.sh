#!/bin/bash
# scripts/audit/security-audit.sh

set -euo pipefail

REPORT_DIR="docs/audits/security"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/security-audit-${TIMESTAMP}.md"

mkdir -p "${REPORT_DIR}"

{
    echo "# Security Hardening Audit: ${TIMESTAMP}"
    echo ""
    
    # Firewall
    echo "## 1. Firewall Status"
    echo ""
    if command -v nft &> /dev/null; then
        echo "### nftables Ruleset"
        echo "\`\`\`"
        sudo nft list ruleset 2>/dev/null || echo "No nftables rules loaded"
        echo "\`\`\`"
    elif command -v iptables &> /dev/null; then
        echo "### iptables Rules (filter table)"
        echo "\`\`\`"
        sudo iptables -L -v -n 2>/dev/null || echo "No iptables rules"
        echo "\`\`\`"
    else
        echo "⚠️ No firewall tool detected!"
    fi
    echo ""
    
    # SSH
    echo "## 2. SSH Security"
    echo ""
    if [[ -f /etc/ssh/sshd_config ]]; then
        echo "### SSH Configuration Highlights"
        echo "\`\`\`"
        grep -E "^(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|PermitEmptyPasswords|Port|Protocol)" /etc/ssh/sshd_config | grep -v "^#" || echo "Defaults are likely in use"
        echo "\`\`\`"
    else
        echo "⚠️ SSH server not installed."
    fi
    echo ""
    
    # Containers
    echo "## 3. Container Isolation (Podman)"
    echo ""
    if command -v podman &> /dev/null; then
        echo "### Podman Version"
        podman version | head -2
        echo ""
        echo "### Rootless Check"
        if podman info 2>&1 | grep -q "rootless: true"; then
            echo "✅ Running in rootless mode."
        else
            echo "❌ Running as root! Review container setup."
        fi
        echo ""
        echo "### Container Network Isolation"
        podman network ls
        echo ""
    else
        echo "Podman not installed."
    fi
    echo ""
    
    # System Hardening
    echo "## 4. System Hardening"
    echo ""
    echo "### Kernel Parameters (sysctl)"
    echo "\`\`\`"
    sysctl kernel.randomize_va_space 2>/dev/null || echo "ASLR status unknown"
    sysctl net.ipv4.conf.all.rp_filter 2>/dev/null || echo "rp_filter status unknown"
    sysctl net.ipv4.tcp_syncookies 2>/dev/null || echo "syncookies status unknown"
    sysctl net.ipv4.ip_forward 2>/dev/null || echo "IP forwarding status unknown"
    echo "\`\`\`"
    echo ""
    
    echo "### Listening Services"
    echo "\`\`\`"
    sudo ss -tulpn | grep LISTEN
    echo "\`\`\`"
    echo ""
    
    # OPSEC
    echo "## 5. OPSEC Hygiene"
    echo ""
    echo "### Shell History Size"
    echo "HISTSIZE: ${HISTSIZE:-Not set}"
    echo "HISTFILESIZE: ${HISTFILESIZE:-Not set}"
    echo ""
    echo "### History Ignore Patterns"
    if [[ -n "${HISTIGNORE:-}" ]]; then
        echo "HISTIGNORE: ${HISTIGNORE}"
    else
        echo "⚠️ No HISTIGNORE set - consider ignoring passwords/tokens."
    fi
    echo ""
    
    # Recommendations
    echo "## 6. Actionable Recommendations"
    echo ""
    # Add dynamic recommendations based on findings (simplified here)
    echo "- Review firewall rules above."
    echo "- If SSH enabled, ensure root login and password auth are disabled."
    echo "- Set HISTIGNORE in your shell rc."
    echo "- Consider using systemd-zram-generator for swap."
    
} | tee "${REPORT_FILE}"

echo "Security audit complete. Report: ${REPORT_FILE}"
