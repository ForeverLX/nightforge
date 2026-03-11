#!/bin/bash
# Git repository awareness (optimized)

if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    REPO=$(basename "$(git rev-parse --show-toplevel)")
    BRANCH=$(git branch --show-current 2>/dev/null)
    
    if git diff --quiet 2>/dev/null && git diff --cached --quiet 2>/dev/null; then
        echo -e "\033[0;32m[✓] Git:\033[0m $REPO ($BRANCH) - clean"
    else
        echo -e "\033[0;33m[~] Git:\033[0m $REPO ($BRANCH) - changes"
    fi
fi
