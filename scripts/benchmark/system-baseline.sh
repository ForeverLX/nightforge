#!/bin/bash
# scripts/benchmark/system-baseline.sh

REPORT_DIR="docs/benchmarks"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="${REPORT_DIR}/baseline-${TIMESTAMP}.txt"

mkdir -p "${REPORT_DIR}"

{
    echo "=== System Performance Baseline: ${TIMESTAMP} ==="
    echo ""
    
    echo "--- Boot Time ---"
    systemd-analyze
    echo ""
    
    echo "--- Userspace Boot Time (critical chain) ---"
    systemd-analyze critical-chain
    echo ""
    
    echo "--- Memory Usage at Baseline ---"
    free -h
    echo ""
    
    echo "--- Swap Usage ---"
    swapon --show
    echo ""
    
    echo "--- Zram Stats (if used) ---"
    zramctl 2>/dev/null || echo "zram not in use"
    echo ""
    
    echo "--- Top 10 Memory Processes ---"
    ps aux --sort=-%mem | head -11
    echo ""
    
    echo "--- CPU Info ---"
    lscpu | grep "Model name"
    lscpu | grep "CPU(s)"
    echo ""
    
    echo "--- Disk IO Stats (simple) ---"
    if command -v iostat &> /dev/null; then
        iostat -x 1 2 | tail -20
    else
        echo "iostat not installed (install sysstat)"
    fi
    echo ""
    
    echo "--- Network Latency (localhost) ---"
    ping -c 3 localhost | tail -3
    echo ""
    
} | tee "${REPORT_FILE}"

echo "Baseline saved to: ${REPORT_FILE}"
