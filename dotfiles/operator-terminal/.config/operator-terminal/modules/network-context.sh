#!/bin/bash
# Network context detection

IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)

if [[ -n "$IP" ]]; then
    if [[ "$IP" == 10.10.* ]]; then
        echo -e "\033[0;33m[!] Network:\033[0m HTB Lab ($IP)"
    elif [[ "$IP" == 10.* ]]; then
        echo -e "\033[0;33m[!] Network:\033[0m Internal ($IP)"
    elif [[ "$IP" == 192.168.* ]]; then
        echo -e "\033[0;36m[~] Network:\033[0m Local Lab ($IP)"
    fi
fi
