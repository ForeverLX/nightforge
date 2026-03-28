---
description: Create a lab instance note (HTB, CWL, pwn.college, Stacksmash)
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /lab <lab-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="10-Projects/Labs/$NOTE_NAME.md" \
  template="Lab-Report" \
  open silent
