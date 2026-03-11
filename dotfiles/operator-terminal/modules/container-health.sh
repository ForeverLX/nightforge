#!/bin/bash
# Enhanced container health monitoring

if ! command -v podman &>/dev/null; then
    return
fi

RUNNING=$(podman ps --format "{{.Names}}" 2>/dev/null | wc -l)
TOTAL=$(podman ps -a --format "{{.Names}}" 2>/dev/null | wc -l)

if (( RUNNING > 0 )); then
    CONTAINERS=$(podman ps --format "{{.Names}}" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
    echo -e "\033[0;32m[✓] Containers:\033[0m $RUNNING/$TOTAL running ($CONTAINERS)"
elif (( TOTAL > 0 )); then
    echo -e "\033[0;33m[~] Containers:\033[0m 0/$TOTAL running (all stopped)"
fi
