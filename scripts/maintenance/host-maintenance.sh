#!/bin/bash
# Host Maintenance System - offsec-workstation
# Purpose: Automated package audit, cleanup, and monitoring
# Author: offsec-workstation project
# Version: 1.0.0
# License: MIT

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-/var/log/offsec-workstation}"
REPORT_DIR="${HOME}/.local/share/offsec-workstation/reports"
INTERACTIVE="${INTERACTIVE:-true}"
DRY_RUN="${DRY_RUN:-false}"
CACHE_SIZE_GB="0"  # Will be populated by check_cache()

# Thresholds
ORPHAN_THRESHOLD=10
CACHE_SIZE_THRESHOLD_GB=5
PACKAGE_AGE_DAYS=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_DIR}/maintenance.log" 2>/dev/null || true
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "${YELLOW}$@${NC}"; }
log_error() { log "ERROR" "${RED}$@${NC}"; }
log_success() { log "SUCCESS" "${GREEN}$@${NC}"; }

# Confirmation prompt
confirm() {
    if [[ "$INTERACTIVE" != "true" ]]; then
        return 0
    fi
    
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "${prompt} [Y/n] " -n 1 -r
    else
        read -p "${prompt} [y/N] " -n 1 -r
    fi
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY && "$default" == "y" ]]; then
        return 0
    else
        return 1
    fi
}

# Initialize directories
init_directories() {
    mkdir -p "$LOG_DIR" 2>/dev/null || sudo mkdir -p "$LOG_DIR"
    mkdir -p "$REPORT_DIR"
}

# System snapshot
create_snapshot() {
    local snapshot_file="$REPORT_DIR/snapshot-$(date +%Y%m%d-%H%M%S).json"
    
    # Don't log here - it interferes with return value
    
    local orphan_count=$(pacman -Qdtq 2>/dev/null | wc -l || echo 0)
    
    cat > "$snapshot_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "packages": {
    "total": $(pacman -Q | wc -l),
    "explicit": $(pacman -Qe | wc -l),
    "orphans": $orphan_count
  },
  "disk": {
    "packages_gb": $(pacman -Qi | awk '/^Installed Size/ {
        size=$4; unit=$5;
        if (unit == "KiB") size=size/1024/1024;
        else if (unit == "MiB") size=size/1024;
        else if (unit == "GiB") size=size;
        else if (unit == "B") size=size/1024/1024/1024;
        total+=size
    } END {printf "%.2f", total}'),
    "cache_gb": $(du -sb /var/cache/pacman/pkg/ 2>/dev/null | awk '{printf "%.2f", $1/1024/1024/1024}' || echo "0")
  },
  "containers": {
    "images": $(podman images --format json 2>/dev/null | jq -s 'length' || echo 0),
    "running": $(podman ps --format json 2>/dev/null | jq -s 'length' || echo 0)
  }
}
EOF
    
    # Return just the filename, no logging
    echo "$snapshot_file"
}

# Check for orphaned packages
check_orphans() {
    log_info "Checking for orphaned packages..."
    
    local orphans
    orphans=$(pacman -Qdtq 2>/dev/null || true)
    local count=$(echo "$orphans" | grep -c '^' || echo 0)
    count=${count%%$'\n'*}  # Remove any trailing newlines
    
    if [[ $count -eq 0 ]]; then
        log_success "No orphaned packages found"
        return 0
    fi
    
    if [[ $count -eq 1 ]]; then
        log_warn "Found 1 orphaned package: $orphans"
    else
        log_warn "Found $count orphaned packages:"
        echo "$orphans" | head -20
        
        if [[ $count -gt 20 ]]; then
            echo "... and $((count - 20)) more"
        fi
    fi
    
    if [[ $count -gt $ORPHAN_THRESHOLD ]]; then
        if confirm "Remove orphaned packages?"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would remove: $orphans"
            else
                sudo pacman -Rns --noconfirm $orphans
                log_success "Removed $count orphaned packages"
            fi
        fi
    fi
}

# Check package cache
check_cache() {
    log_info "Checking package cache..."
    
    local cache_size_bytes=$(sudo du -sb /var/cache/pacman/pkg/ 2>/dev/null | awk '{print $1}')
    CACHE_SIZE_GB=$(awk "BEGIN {printf \"%.2f\", ${cache_size_bytes} / (1024 * 1024 * 1024)}")
    
    log_info "Package cache size: ${CACHE_SIZE_GB} GB"
    
    local threshold_gb=$CACHE_SIZE_THRESHOLD_GB
    
    # Simple comparison using awk
    local over_threshold=$(awk "BEGIN {print (${CACHE_SIZE_GB} > ${threshold_gb})}")
    
    if [[ "$over_threshold" == "1" ]]; then
        log_warn "Cache exceeds ${CACHE_SIZE_THRESHOLD_GB} GB threshold"
        
        if confirm "Clean package cache (keep last 2 versions)?"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would run: paccache -rk2"
            else
                sudo paccache -rk2
                local new_size=$(du -sh /var/cache/pacman/pkg/ 2>/dev/null | cut -f1)
                log_success "Cache cleaned. New size: $new_size"
            fi
        fi
    else
        log_success "Cache size acceptable"
    fi
}

# Check for old packages
check_old_packages() {
    log_info "Checking for old/unused packages..."
    
    local old_packages
    old_packages=$(pacman -Qe | awk '{print $1}' | while read pkg; do
        last_used=$(pacman -Qi "$pkg" 2>/dev/null | grep "Install Date" | cut -d: -f2- | xargs)
        if [[ -n "$last_used" ]]; then
            install_epoch=$(date -d "$last_used" +%s 2>/dev/null || echo 0)
            current_epoch=$(date +%s)
            days_old=$(( (current_epoch - install_epoch) / 86400 ))
            
            if [[ $days_old -gt 365 ]]; then
                echo "$pkg (installed $days_old days ago)"
            fi
        fi
    done)
    
    if [[ -n "$old_packages" ]]; then
        log_warn "Packages installed over 1 year ago:"
        echo "$old_packages" | head -10
        
        local count=$(echo "$old_packages" | wc -l)
        if [[ $count -gt 10 ]]; then
            echo "... and $((count - 10)) more"
        fi
        
        log_info "Review these packages manually - may be unused"
    else
        log_success "No old packages flagged"
    fi
}

# Check for updates
check_updates() {
    log_info "Checking for system updates..."
    
    local updates
    updates=$(checkupdates 2>/dev/null || true)
    local count=0
    if [[ -n "$updates" ]]; then
        count=$(echo "$updates" | grep -c '^' || echo 0)
    fi
    
    if [[ $count -eq 0 ]]; then
        log_success "System is up to date"
        return 0
    fi
    
    log_warn "$count updates available"
    echo "$updates" | head -10
    
    if [[ $count -gt 10 ]]; then
        echo "... and $((count - 10)) more"
    fi
    
    if confirm "Update system now?"; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would run: sudo pacman -Syu"
        else
            sudo pacman -Syu
            log_success "System updated"
        fi
    fi
}

# Security audit
security_audit() {
    log_info "Running security audit..."
    
    # Check for CVEs
    if command -v arch-audit &>/dev/null; then
        local vulns
        vulns=$(arch-audit -u 2>/dev/null || true)
        
        if [[ -n "$vulns" ]]; then
            log_warn "Security vulnerabilities found:"
            echo "$vulns"
        else
            log_success "No known CVEs affecting installed packages"
        fi
    else
        log_warn "arch-audit not installed, skipping CVE check"
    fi
}

# Container health check
check_containers() {
    log_info "Checking container profiles..."
    
    if ! command -v podman &>/dev/null; then
        log_warn "Podman not found, skipping container check"
        return 0
    fi
    
    local expected_profiles=("toolbox" "ad" "re" "web")
    local missing=()
    
    for profile in "${expected_profiles[@]}"; do
        if ! podman images --format "{{.Repository}}" | grep -q "offsec-${profile}"; then
            missing+=("$profile")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Missing container profiles: ${missing[*]}"
        log_info "Run: ./modules/container/scripts/container.sh build-all"
    else
        log_success "All container profiles present"
    fi
    
    # Check for dangling images
    local dangling
    dangling=$(podman images -f "dangling=true" -q 2>/dev/null | wc -l || echo 0)
    
    if [[ $dangling -gt 0 ]]; then
        log_warn "Found $dangling dangling container images"
        
        if confirm "Clean dangling images?"; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would run: podman image prune -f"
            else
                podman image prune -f
                log_success "Cleaned dangling images"
            fi
        fi
    fi
}

# Generate report
generate_report() {
    local snapshot_file="$1"
    local report_file="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S).md"
    
    log_info "Generating maintenance report..."
    
    if [[ ! -f "$snapshot_file" ]]; then
        log_error "Snapshot file not found: $snapshot_file"
        return 1
    fi
    
    cat > "$report_file" << EOF
# Host Maintenance Report
**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Hostname**: $(hostname)  
**Snapshot**: $(basename "$snapshot_file")

## System State

\`\`\`json
$(cat "$snapshot_file")
\`\`\`

## Actions Taken
$(grep "SUCCESS" "${LOG_DIR}/maintenance.log" 2>/dev/null | tail -20 || echo "No recent actions")

## Recommendations
$(grep "WARN" "${LOG_DIR}/maintenance.log" 2>/dev/null | tail -10 || echo "No warnings")

---
Generated by offsec-workstation maintenance system
EOF
    
    log_success "Report saved: $report_file"
    
    # Clean old reports (keep last 30 days)
    cleanup_old_reports
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo
        echo "View report:"
        echo "  cat $report_file"
    fi
}

# Cleanup old reports
cleanup_old_reports() {
    log_info "Cleaning old reports (keeping last 2 snapshots, reports from last 30 days)..."
    
    # Keep only last 2 snapshots
    local snapshots=($(ls -t "$REPORT_DIR"/snapshot-*.json 2>/dev/null))
    if [[ ${#snapshots[@]} -gt 2 ]]; then
        for ((i=2; i<${#snapshots[@]}; i++)); do
            rm -f "${snapshots[$i]}"
            log_info "Removed old snapshot: $(basename "${snapshots[$i]}")"
        done
    fi
    
    # Remove reports older than 30 days
    local count=0
    while IFS= read -r -d '' file; do
        rm -f "$file"
        ((count++))
    done < <(find "$REPORT_DIR" -type f -name "report-*.md" -mtime +30 -print0 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        log_info "Removed $count old report files"
    fi
}

# Main execution
main() {
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  offsec-workstation Host Maintenance System${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════${NC}"
    echo
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN MODE - No changes will be made]${NC}"
        echo
    fi
    
    # Initialize
    init_directories
    
    # Create snapshot
    log_info "Creating system snapshot..."
    local snapshot_file
    snapshot_file=$(create_snapshot)
    log_success "Snapshot saved: $snapshot_file"
    
    # Run checks
    check_orphans
    echo
    
    check_cache
    echo
    
    check_old_packages
    echo
    
    check_updates
    echo
    
    security_audit
    echo
    
    check_containers
    echo
    
    # Generate report
    generate_report "$snapshot_file"
    
    echo
    echo -e "${GREEN}✓ Maintenance complete${NC}"
    echo
    echo "Summary:"
    echo "  Packages: $(pacman -Q | wc -l) total, $(pacman -Qe | wc -l) explicit"
    echo "  Cache: ${CACHE_SIZE_GB:-N/A} GB"
    echo "  Report: $REPORT_DIR/report-$(date +%Y%m%d)*.md"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Options:
  --non-interactive  Run without prompts (for automation)
  --dry-run          Show what would be done without making changes
  --help             Show this help message

Examples:
  # Interactive mode (default)
  $0

  # Automated mode (cron/systemd)
  $0 --non-interactive

  # Test mode
  $0 --dry-run

Environment Variables:
  INTERACTIVE=false      Same as --non-interactive
  DRY_RUN=true          Same as --dry-run
  LOG_DIR=/path/to/logs Custom log directory
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main
main
