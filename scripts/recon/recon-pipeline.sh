#!/bin/bash
# Recon Pipeline - Automated reconnaissance workflow
# Usage: recon-pipeline <domain> [output-dir]

set -euo pipefail

# Configuration
DOMAIN="${1:-}"
OUTPUT_DIR="${2:-$(pwd)/recon-$(date +%Y%m%d-%H%M%S)}"
THREADS=50
WORDLIST_COMMON="/usr/share/wordlists/dirb/common.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    cat << EOF
Usage: $(basename "$0") <domain> [output-dir]

Automated reconnaissance pipeline for external pentests.

Stages:
  1. Subdomain Enumeration (subfinder, amass)
  2. DNS Resolution (dnsx)
  3. Port Scanning (nmap)
  4. HTTP Detection (httpx)
  5. Tech Fingerprinting (whatweb)
  6. Vulnerability Scanning (nuclei)
  7. Report Generation (markdown)

Examples:
  $(basename "$0") example.com
  $(basename "$0") target.com ./engage/target-recon

Output Structure:
  \$OUTPUT_DIR/
    ├── subdomains.txt       # All discovered subdomains
    ├── resolved.txt         # DNS-resolved hosts
    ├── nmap/                # Nmap scan results
    ├── http-hosts.txt       # Live HTTP services
    ├── tech-stack.txt       # Technology fingerprints
    ├── vulnerabilities.txt  # Nuclei findings
    └── REPORT.md            # Final markdown report
EOF
    exit 1
}

log() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

banner() {
    cat << 'EOF'
    ____                          ____  _            ___            
   / __ \___  _________  ____    / __ \(_)___  ___  / (_)___  ___   
  / /_/ / _ \/ ___/ __ \/ __ \  / /_/ / / __ \/ _ \/ / / __ \/ _ \  
 / _, _/  __/ /__/ /_/ / / / / / ____/ / /_/ /  __/ / / / / /  __/  
/_/ |_|\___/\___/\____/_/ /_/ /_/   /_/ .___/\___/_/_/_/ /_/\___/   
                                     /_/                             
EOF
    echo ""
    echo -e "${CYAN}Target: ${DOMAIN}${NC}"
    echo -e "${CYAN}Output: ${OUTPUT_DIR}${NC}"
    echo ""
}

# Validate inputs
if [[ -z "$DOMAIN" ]]; then
    usage
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"/{nmap,screenshots}
cd "$OUTPUT_DIR"

# Start timer
START_TIME=$(date +%s)

banner

# Stage 1: Subdomain Enumeration
log "Stage 1: Subdomain Enumeration"
{
    subfinder -d "$DOMAIN" -silent -o subdomains-subfinder.txt || true
    
    # Note: amass skipped (large dependency, install separately if needed)
    # amass enum -passive -d "$DOMAIN" -o subdomains-amass.txt || true
    
    # Use only subfinder results
    cat subdomains-*.txt 2>/dev/null | sort -u > subdomains.txt
    SUBDOMAIN_COUNT=$(wc -l < subdomains.txt)
    
    if [[ $SUBDOMAIN_COUNT -gt 0 ]]; then
        log_success "Found $SUBDOMAIN_COUNT subdomains"
    else
        log_warn "No subdomains found"
    fi
}

# Stage 2: DNS Resolution
log "Stage 2: DNS Resolution"
{
    if [[ -s subdomains.txt ]]; then
        dnsx -l subdomains.txt -silent -o resolved.txt || true
        RESOLVED_COUNT=$(wc -l < resolved.txt 2>/dev/null || echo 0)
        log_success "Resolved $RESOLVED_COUNT hosts"
    else
        log_warn "No subdomains to resolve"
        echo "$DOMAIN" > resolved.txt
    fi
}

# Stage 3: Port Scanning
log "Stage 3: Port Scanning (nmap)"
{
    if [[ -s resolved.txt ]]; then
        nmap -iL resolved.txt \
            -p- \
            --min-rate 10000 \
            -oA nmap/full-scan \
            -T4 \
            --open \
            2>/dev/null || true
        
        # Quick service detection on open ports
        if [[ -f nmap/full-scan.gnmap ]]; then
            grep -oP '\d+/open' nmap/full-scan.gnmap | cut -d'/' -f1 | sort -u > nmap/open-ports.txt || true
            PORT_COUNT=$(wc -l < nmap/open-ports.txt 2>/dev/null || echo 0)
            log_success "Found $PORT_COUNT open ports"
        fi
    else
        log_warn "No hosts to scan"
    fi
}

# Stage 4: HTTP Detection
log "Stage 4: HTTP Service Detection"
{
    if [[ -s resolved.txt ]]; then
        # Create URLs file for httpx
        awk '{print "http://"$1"\nhttps://"$1}' resolved.txt > urls-to-probe.txt
        
        httpx -l urls-to-probe.txt \
            -silent \
            -status-code \
            -tech-detect \
            -title \
            > http-hosts.txt 2>&1 || true
        
        HTTP_COUNT=$(grep -c "http" http-hosts.txt 2>/dev/null || echo 0)
        log_success "Found $HTTP_COUNT HTTP services"
        
        # Extract URLs for next stages
        grep -oP 'https?://[^\s]+' http-hosts.txt > urls-only.txt 2>/dev/null || touch urls-only.txt
    else
        log_warn "No hosts to probe"
        HTTP_COUNT=0
        touch http-hosts.txt urls-only.txt
    fi
}

# Stage 5: Technology Fingerprinting
log "Stage 5: Technology Fingerprinting"
{
    if [[ -s http-hosts.txt ]]; then
        # Extract URLs only
        grep -oP 'https?://[^\s]+' http-hosts.txt > urls-only.txt || true
        
        whatweb -i urls-only.txt \
            --color=never \
            --quiet \
            --log-brief=tech-stack.txt || true
        
        log_success "Technology fingerprinting complete"
    else
        log_warn "No HTTP services to fingerprint"
    fi
}

# Stage 6: Vulnerability Scanning
log "Stage 6: Vulnerability Scanning (nuclei)"
VULN_COUNT=0
{
    if command -v nuclei &> /dev/null; then
        if [[ -s urls-only.txt ]]; then
            nuclei -l urls-only.txt \
                -severity critical,high,medium \
                -silent \
                -o vulnerabilities.txt || true
            
            VULN_COUNT=$(wc -l < vulnerabilities.txt 2>/dev/null || echo 0)
            
            if [[ $VULN_COUNT -gt 0 ]]; then
                log_warn "Found $VULN_COUNT potential vulnerabilities"
            else
                log_success "No vulnerabilities detected"
            fi
        else
            log_warn "No targets for vulnerability scan"
        fi
    else
        log_warn "nuclei not installed - skipping vulnerability scan"
        echo "# nuclei not available - install with: go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" > vulnerabilities.txt
    fi
}

# Stage 7: Generate Report
log "Stage 7: Generating Report"
{
    cat > REPORT.md << REPORT_EOF
# Reconnaissance Report: ${DOMAIN}

**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Target**: \`${DOMAIN}\`  
**Output Directory**: \`${OUTPUT_DIR}\`

---

## Summary

| Metric | Count |
|--------|-------|
| Subdomains Discovered | ${SUBDOMAIN_COUNT} |
| Hosts Resolved | ${RESOLVED_COUNT} |
| Open Ports | ${PORT_COUNT} |
| HTTP Services | ${HTTP_COUNT} |
| Vulnerabilities | ${VULN_COUNT} |

---

## Subdomains

\`\`\`
$(cat subdomains.txt 2>/dev/null | head -20)
$(if [[ $SUBDOMAIN_COUNT -gt 20 ]]; then echo "... and $((SUBDOMAIN_COUNT - 20)) more"; fi)
\`\`\`

---

## HTTP Services

\`\`\`
$(cat http-hosts.txt 2>/dev/null | head -20)
$(if [[ $HTTP_COUNT -gt 20 ]]; then echo "... and $((HTTP_COUNT - 20)) more"; fi)
\`\`\`

---

## Technology Stack

\`\`\`
$(cat tech-stack.txt 2>/dev/null | head -30)
\`\`\`

---

## Vulnerabilities

$(if [[ -s vulnerabilities.txt ]]; then
    echo "\`\`\`"
    cat vulnerabilities.txt
    echo "\`\`\`"
    echo ""
    echo "⚠️ **CRITICAL**: Review vulnerabilities and prioritize exploitation"
else
    echo "✅ No vulnerabilities detected by automated scan."
    echo ""
    echo "**Note**: Manual testing still required."
fi)

---

## Open Ports

$(if [[ -f nmap/open-ports.txt ]]; then
    echo "\`\`\`"
    cat nmap/open-ports.txt | head -50
    echo "\`\`\`"
else
    echo "No port scan results available."
fi)

---

## Files

- \`subdomains.txt\` - All discovered subdomains
- \`resolved.txt\` - DNS-resolved hosts
- \`nmap/\` - Nmap scan results
- \`http-hosts.txt\` - Live HTTP services
- \`tech-stack.txt\` - Technology fingerprints
- \`vulnerabilities.txt\` - Nuclei findings

---

## Next Steps

1. **Manual verification** of discovered assets
2. **Content discovery** on HTTP services (gobuster, ffuf)
3. **Authentication testing** on identified login portals
4. **Exploit development** for discovered vulnerabilities
5. **Social engineering** against identified email addresses
6. **Network pivoting** from compromised hosts

---

**Generated by**: offsec-workstation recon-pipeline  
**Container**: offsec-web:0.5.0
REPORT_EOF

    log_success "Report generated: REPORT.md"
}

# Calculate runtime
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Reconnaissance Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${CYAN}Runtime: ${RUNTIME}s${NC}"
echo -e "${CYAN}Report: ${OUTPUT_DIR}/REPORT.md${NC}"
echo ""

# Open report if in interactive terminal
if [[ -t 1 ]]; then
    echo -e "View report: ${YELLOW}cat ${OUTPUT_DIR}/REPORT.md${NC}"
fi
