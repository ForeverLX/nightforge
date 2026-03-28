#!/bin/bash
# Lab infrastructure detection

# Check Proxmox VMs (if configured)
if command -v pvesh &>/dev/null; then
    RUNNING_VMS=$(pvesh get /cluster/resources --type vm 2>/dev/null | grep running | wc -l)
    if (( RUNNING_VMS > 0 )); then
        echo -e "\033[0;32m[✓] Lab:\033[0m $RUNNING_VMS Proxmox VMs running"
    fi
fi

# Future: Check Ludus
# if command -v ludus &>/dev/null; then
#     ludus status
# fi
