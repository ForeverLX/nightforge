#!/bin/bash
# Warn if disk space critical

HOME_USAGE=$(df -h /home | awk 'NR==2 {print $5}' | sed 's/%//')
ROOT_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

if (( HOME_USAGE > 80 )); then
    echo -e "\033[0;31m[⚠] Disk:\033[0m /home at ${HOME_USAGE}% (clean up loot/screenshots)"
elif (( ROOT_USAGE > 80 )); then
    echo -e "\033[0;31m[⚠] Disk:\033[0m / at ${ROOT_USAGE}% (clear package cache)"
fi
