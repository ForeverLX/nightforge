#!/bin/bash
# Podman container status

if ! command -v podman &>/dev/null; then
    return
fi

RUNNING=$(podman ps --format "{{.Names}}" 2>/dev/null | wc -l)
if (( RUNNING > 0 )); then
    CONTAINERS=$(podman ps --format "{{.Names}}" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
    echo -e "\033[0;32m[✓] Containers:\033[0m $RUNNING running ($CONTAINERS)"
fi
