#!/bin/bash
# Detect special workspace modes

if [[ -f ".exploitdev" ]] || [[ "$PWD" == *"/exploitdev"* ]] || [[ "$PWD" == *"/research"* ]]; then
    echo -e "\033[1;31m[⚠] MODE:\033[0m Exploit Development"
elif [[ "$PWD" == *"/engage/"* ]]; then
    ENGAGEMENT=$(basename "$PWD")
    echo -e "\033[1;33m[!] ENGAGEMENT:\033[0m $ENGAGEMENT"
fi
