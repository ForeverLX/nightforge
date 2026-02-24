#!/bin/bash
# Recon Pipeline - Automated reconnaissance workflow (FIXED)
# Usage: recon-pipeline <domain> [output-dir]

set -euo pipefail

# Configuration
DOMAIN="${1:-}"
OUTPUT_DIR="${2:-$(pwd)/recon-$(date +%Y%m%d-%H%M%S)}"
THREADS=50
WORDLIST_COMMON="/usr/share/wordlists/dirb/common.txt"

# Initialize counters (FIX: initialize all variables)
SUBDOMAIN_COUNT=0
RESOLVED_COUNT=0
PORT_COUNT=0
HTTP_COUNT=0
VULN_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')]${NC} ${BLUE}$*${NC}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
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
}

usage() {
    cat << EOF
Usage: $(basename "$0") <domain> [output-dir]

Automated reconnaissance pipeline with 7 stages:
  1. Subdomain Enumeration (subfinder)
  2. DNS Resolution (dnsx)  
  3. Port Scanning (nmap)
  4. HTTP Detection (httpx)
  5. Technology Fingerprinting (whatweb)
  6. Vulnerability Scanning (nuclei - optional)
  7. Report Generation (markdown)

Examples:
  $(basename "$0") example.com
  $(basename "$0") example.com /tmp/recon-output
  
Notes:
  - Provide DOMAIN only (not full URL)
  - Output directory created automatically if not specified
  - Requires: subfinder, dnsx, nmap, httpx, whatweb
  - Optional: nuclei (for vulnerability scanning)
EOF
    exit 1
}

# FIX: Extract domain from URL if provided
extract_domain() {
    local input="$1"
    
    # Remove protocol
    input="${input#http://}"
    input="${input#https://}"
    
    # Remove path
    input="${input%%/*}"
    
    # Remove port
    input="${input%%:*}"
    
    echo "$input"
}

# Validate input
if [[ -z "$DOMAIN" ]] || [[ "$DOMAIN" == "--help" ]] || [[ "$DOMAIN" == "-h" ]]; then
    usage
fi

# FIX: Handle URLs by extracting domain
if [[ "$DOMAIN" =~ ^https?:// ]]; then
    log_warn "URL detected, extracting domain..."
    ORIGINAL_INPUT="$DOMAIN"
    DOMAIN=$(extract_domain "$DOMAIN")
    log "Extracted domain: $DOMAIN"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"/{nmap,screenshots}
cd "$OUTPUT_DIR"

# Start
START_TIME=$(date +%s)
banner
echo ""
echo "Target: $DOMAIN"
echo "Output: $OUTPUT_DIR"

# Stage 1: Subdomain Enumeration
log "Stage 1: Subdomain Enumeration"
{
    subfinder -d "$DOMAIN" \
        -all \
        -silent \
        -o subdomains.txt || true
    
    SUBDOMAIN_COUNT=$(wc -l < subdomains.txt 2>/dev/null || echo 0)
    
    if [[ $SUBDOMAIN_COUNT -eq 0 ]]; then
        log_warn "No subdomains found"
        # Add the domain itself
        echo "$DOMAIN" > subdomains.txt
        SUBDOMAIN_COUNT=1
    else
        log_success "Found $SUBDOMAIN_COUNT subdomains"
    fi
}

# Stage 2: DNS Resolution
log "Stage 2: DNS Resolution"
{
    if [[ -s subdomains.txt ]]; then
        dnsx -l subdomains.txt \
            -silent \
            -a \
            -resp-only \
            -o resolved.txt || true
        
        RESOLVED_COUNT=$(wc -l < resolved.txt 2>/dev/null || echo 0)
        
        if [[ $RESOLVED_COUNT -eq 0 ]]; then
            log_warn "No subdomains resolved"
        else
            log_success "Resolved $RESOLVED_COUNT hosts"
        fi
    else
        log_warn "No subdomains to resolve"
        RESOLVED_COUNT=0
    fi
}

# Stage 3: Port Scanning
log "Stage 3: Port Scanning (nmap)"
{
    if [[ -s resolved.txt ]]; then
        # Use TCP connect scan (-sT) instead of SYN (-sS) for containers
        # Remove --defeat-rst-ratelimit which requires SYN scan
        nmap -iL resolved.txt \
            -p- \
            -sT \
            --min-rate 1000 \
            -T4 \
            -oA nmap/full-scan 2>&1 | tee nmap/scan.log || true
        
        # Extract open ports from nmap output
        if [[ -f "nmap/full-scan.nmap" ]]; then
            # Extract port numbers from lines like "80/tcp   open  http"
            grep "open" nmap/full-scan.nmap | grep -oP '^\d+' | sort -u > open-ports.txt 2>/dev/null || true
        else
            touch open-ports.txt
        fi
        
        PORT_COUNT=$(wc -l < open-ports.txt 2>/dev/null || echo 0)
        
        if [[ $PORT_COUNT -gt 0 ]]; then
            log_success "Found $PORT_COUNT open ports"
        else
            log_warn "No open ports found"
        fi
    else
        log_warn "No hosts to scan"
        PORT_COUNT=0
        touch open-ports.txt
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
    if [[ -s urls-only.txt ]]; then
        # Run whatweb and capture output (ignore warnings about Ruby 3.4)
        if xargs -a urls-only.txt -I {} whatweb -a 3 --quiet {} > tech-stack.txt 2>&1; then
            # Check if we got actual results (not just error messages)
            if grep -qE "http|IP|Country" tech-stack.txt 2>/dev/null; then
                log_success "Technology fingerprinting complete"
            else
                log_warn "whatweb produced no results"
            fi
        else
            log_warn "whatweb encountered errors"
        fi
    else
        log_warn "No HTTP services to fingerprint"
        touch tech-stack.txt
    fi
}

# Stage 6: Vulnerability Scanning
log "Stage 6: Vulnerability Scanning (nuclei)"
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
            VULN_COUNT=0
        fi
    else
        log_warn "nuclei not installed - skipping vulnerability scan"
        echo "# nuclei not available - install with: go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest" > vulnerabilities.txt
        VULN_COUNT=0
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
$(head -20 subdomains.txt 2>/dev/null || echo "None found")
$(if [[ $SUBDOMAIN_COUNT -gt 20 ]]; then echo "... and $(($SUBDOMAIN_COUNT - 20)) more"; fi)
\`\`\`

---

## HTTP Services

\`\`\`
$(cat http-hosts.txt 2>/dev/null || echo "None found")
\`\`\`

---

## Technology Stack

\`\`\`
$(cat tech-stack.txt 2>/dev/null || echo "Not available")
\`\`\`

---

## Vulnerabilities

\`\`\`
$(cat vulnerabilities.txt 2>/dev/null || echo "None detected or nuclei not installed")
\`\`\`

$(if [[ $VULN_COUNT -gt 0 ]]; then echo "⚠️ **CRITICAL**: Review vulnerabilities and prioritize exploitation"; fi)

---

## Open Ports

\`\`\`
$(cat open-ports.txt 2>/dev/null || echo "None found")
\`\`\`

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

# Summary
END_TIME=$(date +%s)
RUNTIME=$((END_TIME - START_TIME))

echo ""
echo "═══════════════════════════════════════════════"
echo "  Reconnaissance Complete"
echo "═══════════════════════════════════════════════"
echo "Runtime: ${RUNTIME}s"
echo "Report: $OUTPUT_DIR/REPORT.md"
echo "View report: cat $OUTPUT_DIR/REPORT.md"
