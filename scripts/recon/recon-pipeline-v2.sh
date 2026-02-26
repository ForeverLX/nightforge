#!/bin/bash
# Modern Reconnaissance Pipeline v2.0
# Based on: Jason Haddix TBHM v4 Methodology
# Tools: amass, naabu, httpx, dnsx, ffuf, webanalyze, gitleaks, cloud_enum

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║          Modern Recon Pipeline v2.0                      ║
║          Methodology: TBHM v4 (Jason Haddix)             ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] <target>

OPTIONS:
    -m, --mode      Recon mode (fast|balanced|deep) [default: balanced]
    -o, --output    Output directory [default: ./recon-<target>]
    -h, --help      Show this help message

MODES:
    fast        Passive subdomain enum + quick port scan (15-30 min)
    balanced    Active subdomain enum + full port scan + HTTP probing (1-2 hrs)
    deep        Everything + content discovery + GitHub secrets (4-8 hrs)

EXAMPLES:
    $0 target.com
    $0 -m fast target.com
    $0 -m deep -o /work/results target.com

PHASES:
    1. Asset Discovery (subdomains, DNS, cloud assets)
    2. Service Discovery (ports, HTTP services)
    3. Deep Enumeration (content, tech stack, secrets)
    4. Reporting (consolidated findings)
EOF
    exit 1
}

# Default values
MODE="balanced"
OUTPUT_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1"
            usage
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Validate target
if [ -z "${TARGET:-}" ]; then
    echo -e "${RED}[ERROR]${NC} Target domain required"
    usage
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="./recon-${TARGET}"
fi

# Create output structure
mkdir -p "$OUTPUT_DIR"/{subdomains,dns,ports,http,content,tech,secrets,cloud}

echo -e "${GREEN}[*]${NC} Target: ${TARGET}"
echo -e "${GREEN}[*]${NC} Mode: ${MODE}"
echo -e "${GREEN}[*]${NC} Output: ${OUTPUT_DIR}"
echo ""

# Logging
LOGFILE="$OUTPUT_DIR/pipeline.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

# Start time
START_TIME=$(date +%s)

# Initialize counters to prevent unbound variable errors
SUBDOMAIN_COUNT=0
RESOLVED_COUNT=0
PORT_COUNT=0
HTTP_COUNT=0
TECH_COUNT=0
CLOUD_COUNT=0

# ============================================================================
# PHASE 1: ASSET DISCOVERY
# ============================================================================

echo -e "${BLUE}[PHASE 1]${NC} Asset Discovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1.1 - Subdomain Enumeration
echo -e "${YELLOW}[1.1]${NC} Subdomain Enumeration (amass)"

if [ "$MODE" = "fast" ]; then
    # Passive only
    echo "  → Running passive enumeration..."
    echo -e "  ${BLUE}ℹ${NC} This may take 2-5 minutes..."
    
    # Show spinner while amass runs
    amass enum -d "$TARGET" -passive -o "$OUTPUT_DIR/subdomains/amass-passive.txt" 2>/dev/null &
    AMASS_PID=$!
    
    # Spinner
    spin='-\|/'
    i=0
    while kill -0 $AMASS_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r  ${spin:$i:1} Enumerating..."
        sleep .1
    done
    wait $AMASS_PID
    printf "\r  ✓ Enumeration complete     \n"
    
elif [ "$MODE" = "balanced" ]; then
    # Active enumeration
    echo "  → Running active enumeration..."
    echo -e "  ${BLUE}ℹ${NC} This may take 10-15 minutes..."
    
    amass enum -d "$TARGET" -active -o "$OUTPUT_DIR/subdomains/amass-active.txt" 2>/dev/null &
    AMASS_PID=$!
    
    # Progress indicator
    spin='-\|/'
    i=0
    while kill -0 $AMASS_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r  ${spin:$i:1} Enumerating (active scan)..."
        sleep .1
    done
    wait $AMASS_PID
    printf "\r  ✓ Enumeration complete               \n"
    
elif [ "$MODE" = "deep" ]; then
    # Active + brute force
    echo "  → Running active enumeration with brute force..."
    echo -e "  ${BLUE}ℹ${NC} This may take 30-60 minutes..."
    
    amass enum -d "$TARGET" -active -brute -o "$OUTPUT_DIR/subdomains/amass-deep.txt" 2>/dev/null &
    AMASS_PID=$!
    
    # Progress with counter
    spin='-\|/'
    i=0
    elapsed=0
    while kill -0 $AMASS_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        elapsed=$((elapsed + 1))
        minutes=$((elapsed / 600))
        printf "\r  ${spin:$i:1} Enumerating (deep scan) - ${minutes}m elapsed..."
        sleep .1
    done
    wait $AMASS_PID
    printf "\r  ✓ Enumeration complete                                \n"
fi

# Consolidate subdomains and filter only FQDNs
cat "$OUTPUT_DIR"/subdomains/amass-*.txt 2>/dev/null | \
    grep -E '\(FQDN\)' | \
    awk '{print $1}' | \
    sort -u > "$OUTPUT_DIR/subdomains/all-subdomains.txt" || true

# If no subdomains found, add the target itself
if [ ! -s "$OUTPUT_DIR/subdomains/all-subdomains.txt" ]; then
    echo "$TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
    echo -e "  ${BLUE}ℹ${NC} No subdomains found, using target directly"
fi

SUBDOMAIN_COUNT=$(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt" 2>/dev/null || echo 0)
echo -e "  ${GREEN}✓${NC} Found ${SUBDOMAIN_COUNT} subdomain(s)"

# 1.2 - DNS Resolution
echo -e "${YELLOW}[1.2]${NC} DNS Resolution (dnsx)"
if [ -s "$OUTPUT_DIR/subdomains/all-subdomains.txt" ]; then
    dnsx -l "$OUTPUT_DIR/subdomains/all-subdomains.txt" -a -resp -silent -o "$OUTPUT_DIR/dns/resolved.txt" 2>/dev/null || true
    RESOLVED_COUNT=$(wc -l < "$OUTPUT_DIR/dns/resolved.txt" 2>/dev/null || echo 0)
    
    if [ "$RESOLVED_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Resolved ${RESOLVED_COUNT} domain(s)"
        # Extract just hostnames
        cut -d' ' -f1 "$OUTPUT_DIR/dns/resolved.txt" > "$OUTPUT_DIR/dns/live-hosts.txt" 2>/dev/null || true
    else
        echo -e "  ${RED}✗${NC} No domains resolved"
    fi
else
    echo -e "  ${RED}✗${NC} No subdomains to resolve"
fi

# 1.3 - Cloud Asset Discovery
if [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; then
    echo -e "${YELLOW}[1.3]${NC} Cloud Asset Discovery (cloud_enum)"
    
    # Extract base keyword from domain
    KEYWORD=$(echo "$TARGET" | cut -d'.' -f1)
    
    echo "  → Searching for cloud assets with keyword: ${KEYWORD}"
    cloud_enum -k "$KEYWORD" -l "$OUTPUT_DIR/cloud/findings.txt" --disable-gcp 2>/dev/null || true
    
    if [ -s "$OUTPUT_DIR/cloud/findings.txt" ]; then
        CLOUD_COUNT=$(grep -c "Found" "$OUTPUT_DIR/cloud/findings.txt" 2>/dev/null || echo 0)
        echo -e "  ${GREEN}✓${NC} Found ${CLOUD_COUNT} cloud assets"
    else
        echo -e "  ${BLUE}ℹ${NC} No cloud assets found"
    fi
fi

echo ""

# ============================================================================
# PHASE 2: SERVICE DISCOVERY
# ============================================================================

echo -e "${BLUE}[PHASE 2]${NC} Service Discovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 2.1 - Port Scanning
echo -e "${YELLOW}[2.1]${NC} Port Scanning"

if [ -s "$OUTPUT_DIR/dns/live-hosts.txt" ]; then
    HOST_COUNT=$(wc -l < "$OUTPUT_DIR/dns/live-hosts.txt")
    
    if [ "$MODE" = "fast" ]; then
        # Top 1000 ports with naabu
        echo "  → Scanning top 1000 ports (naabu) on ${HOST_COUNT} hosts..."
        echo -e "  ${BLUE}ℹ${NC} Estimated time: 1-3 minutes"
        
        naabu -l "$OUTPUT_DIR/dns/live-hosts.txt" -top-ports 1000 -silent -o "$OUTPUT_DIR/ports/open-ports.txt" 2>/dev/null &
        NAABU_PID=$!
        
        # Progress spinner
        spin='-\|/'
        i=0
        while kill -0 $NAABU_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  ${spin:$i:1} Scanning ports..."
            sleep .1
        done
        wait $NAABU_PID
        printf "\r  ✓ Port scan complete     \n"
        
    elif [ "$MODE" = "balanced" ]; then
        # Full port scan with naabu
        echo "  → Scanning all ports (naabu) on ${HOST_COUNT} hosts..."
        echo -e "  ${BLUE}ℹ${NC} Estimated time: 5-10 minutes"
        
        naabu -l "$OUTPUT_DIR/dns/live-hosts.txt" -p - -silent -o "$OUTPUT_DIR/ports/open-ports.txt" 2>/dev/null &
        NAABU_PID=$!
        
        spin='-\|/'
        i=0
        while kill -0 $NAABU_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  ${spin:$i:1} Scanning all 65535 ports..."
            sleep .1
        done
        wait $NAABU_PID
        printf "\r  ✓ Port scan complete                    \n"
        
    elif [ "$MODE" = "deep" ]; then
        # RustScan + nmap service detection
        echo "  → Fast port discovery (rustscan) + service detection (nmap)..."
        echo -e "  ${BLUE}ℹ${NC} Estimated time: 10-20 minutes"
        
        current=0
        while IFS= read -r host; do
            current=$((current + 1))
            printf "\r  [%d/%d] Scanning %s..." "$current" "$HOST_COUNT" "$host"
            rustscan -a "$host" --ulimit 5000 -- -sV -sC -oN "$OUTPUT_DIR/ports/${host}-nmap.txt" 2>/dev/null || true
        done < "$OUTPUT_DIR/dns/live-hosts.txt"
        printf "\n"
        
        # Consolidate ports
        grep -h "open" "$OUTPUT_DIR"/ports/*-nmap.txt 2>/dev/null | awk '{print $1}' | sort -u > "$OUTPUT_DIR/ports/open-ports.txt" || true
    fi
    
    PORT_COUNT=$(wc -l < "$OUTPUT_DIR/ports/open-ports.txt" 2>/dev/null || echo 0)
    echo -e "  ${GREEN}✓${NC} Found ${PORT_COUNT} open ports"
else
    echo -e "  ${RED}✗${NC} No live hosts to scan"
fi

# 2.2 - HTTP Service Probing
echo -e "${YELLOW}[2.2]${NC} HTTP Service Probing (httpx)"

if [ -s "$OUTPUT_DIR/dns/live-hosts.txt" ]; then
    httpx -l "$OUTPUT_DIR/dns/live-hosts.txt" \
        -tech-detect \
        -status-code \
        -title \
        -json \
        -silent \
        -o "$OUTPUT_DIR/http/http-services.json" 2>/dev/null || true
    
    HTTP_COUNT=$(wc -l < "$OUTPUT_DIR/http/http-services.json" 2>/dev/null || echo 0)
    
    if [ "$HTTP_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Found ${HTTP_COUNT} HTTP service(s)"
        # Extract URLs
        jq -r '.url' "$OUTPUT_DIR/http/http-services.json" 2>/dev/null | sort -u > "$OUTPUT_DIR/http/live-urls.txt" || true
    else
        echo -e "  ${BLUE}ℹ${NC} No HTTP services found"
    fi
else
    echo -e "  ${RED}✗${NC} No hosts to probe"
fi

echo ""

# ============================================================================
# PHASE 3: DEEP ENUMERATION
# ============================================================================

if [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; then
    echo -e "${BLUE}[PHASE 3]${NC} Deep Enumeration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 3.1 - Technology Stack Detection
    echo -e "${YELLOW}[3.1]${NC} Technology Stack (webanalyze)"
    
    if [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
        webanalyze -hosts "$OUTPUT_DIR/http/live-urls.txt" \
            -output json \
            -silent > "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null || true
        
        TECH_COUNT=$(jq -r '.matches[].app_name' "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null | sort -u | wc -l || echo 0)
        
        if [ "$TECH_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Detected ${TECH_COUNT} technologies"
        else
            echo -e "  ${BLUE}ℹ${NC} No technologies detected"
        fi
    else
        echo -e "  ${RED}✗${NC} No URLs to analyze"
    fi
    
    # 3.2 - Content Discovery (only in deep mode)
    if [ "$MODE" = "deep" ] && [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
        echo -e "${YELLOW}[3.2]${NC} Content Discovery (ffuf)"
        echo "  → Fuzzing common paths (this may take a while)..."
        
        # Note: Requires wordlist - using common paths
        WORDLIST="/usr/share/wordlists/dirb/common.txt"
        
        if [ -f "$WORDLIST" ]; then
            while IFS= read -r url; do
                domain=$(echo "$url" | awk -F/ '{print $3}')
                ffuf -w "$WORDLIST" \
                    -u "${url}/FUZZ" \
                    -mc 200,301,302,401,403 \
                    -o "$OUTPUT_DIR/content/${domain}-ffuf.json" \
                    -of json \
                    -s \
                    2>/dev/null || true
            done < "$OUTPUT_DIR/http/live-urls.txt"
            
            echo -e "  ${GREEN}✓${NC} Content discovery complete"
        else
            echo -e "  ${YELLOW}⚠${NC} Wordlist not found, skipping content discovery"
        fi
    fi
    
    # 3.3 - GitHub Secret Scanning (only in deep mode)
    if [ "$MODE" = "deep" ]; then
        echo -e "${YELLOW}[3.3]${NC} GitHub Secret Scanning (gitleaks)"
        
        # Extract organization name from domain
        ORG=$(echo "$TARGET" | cut -d'.' -f1)
        
        echo "  → Checking GitHub organization: ${ORG}"
        echo "  ${YELLOW}ℹ${NC} Requires GitHub token (GITHUB_TOKEN env var)"
        
        if [ -n "${GITHUB_TOKEN:-}" ]; then
            gitleaks detect \
                --source "https://github.com/${ORG}" \
                --report-path "$OUTPUT_DIR/secrets/gitleaks-report.json" \
                --verbose 2>/dev/null || true
            
            if [ -s "$OUTPUT_DIR/secrets/gitleaks-report.json" ]; then
                SECRET_COUNT=$(jq length "$OUTPUT_DIR/secrets/gitleaks-report.json" 2>/dev/null || echo 0)
                echo -e "  ${GREEN}✓${NC} Found ${SECRET_COUNT} potential secrets"
            else
                echo -e "  ${BLUE}ℹ${NC} No secrets found"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} Skipping (no GITHUB_TOKEN set)"
        fi
    fi
    
    echo ""
fi

# ============================================================================
# PHASE 4: REPORTING
# ============================================================================

echo -e "${BLUE}[PHASE 4]${NC} Generating Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Generate summary report
REPORT="$OUTPUT_DIR/REPORT.md"

cat > "$REPORT" << EOF
# Reconnaissance Report: ${TARGET}

**Date:** $(date)  
**Mode:** ${MODE}  
**Duration:** $(($(date +%s) - START_TIME)) seconds

---

## Summary

| Metric | Count |
|--------|-------|
| Subdomains Discovered | ${SUBDOMAIN_COUNT} |
| Live Hosts | ${RESOLVED_COUNT} |
| Open Ports | ${PORT_COUNT} |
| HTTP Services | ${HTTP_COUNT} |
| Technologies Detected | ${TECH_COUNT:-0} |

---

## Subdomain Enumeration

**Method:** $([ "$MODE" = "fast" ] && echo "Passive" || echo "Active")  
**Tool:** amass

\`\`\`
$(head -20 "$OUTPUT_DIR/subdomains/all-subdomains.txt" 2>/dev/null || echo "No subdomains found")
\`\`\`

$([ ${SUBDOMAIN_COUNT} -gt 20 ] && echo "*(Showing first 20 of ${SUBDOMAIN_COUNT} total)*")

---

## Live HTTP Services

\`\`\`
$(head -20 "$OUTPUT_DIR/http/live-urls.txt" 2>/dev/null || echo "No HTTP services found")
\`\`\`

$([ ${HTTP_COUNT} -gt 20 ] && echo "*(Showing first 20 of ${HTTP_COUNT} total)*")

---

## Technology Stack

$(jq -r '.matches[] | "- \(.app_name) (\(.version // "version unknown"))"' "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null | sort -u | head -20 || echo "No technologies detected")

---

## Next Steps

1. **Manual Review:** Review HTTP services for interesting targets
2. **Screenshot:** Take screenshots of high-value targets
3. **Deep Dive:** Focus on specific services for vulnerability testing
4. **Content Discovery:** Run deeper content discovery on key targets
5. **Authentication:** Test for default credentials

---

## File Structure

\`\`\`
$(tree -L 2 "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type f)
\`\`\`

---

**Report generated by:** Modern Recon Pipeline v2.0  
**Methodology:** TBHM v4 (Jason Haddix)
EOF

echo -e "${GREEN}✓${NC} Report generated: ${REPORT}"
echo ""

# ============================================================================
# COMPLETION
# ============================================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${GREEN}[SUCCESS]${NC} Reconnaissance complete!"
echo -e "${GREEN}[*]${NC} Duration: ${MINUTES}m ${SECONDS}s"
echo -e "${GREEN}[*]${NC} Results: ${OUTPUT_DIR}"
echo -e "${GREEN}[*]${NC} Report: ${REPORT}"
echo ""
echo -e "${BLUE}Next:${NC} Review ${REPORT} for findings"
