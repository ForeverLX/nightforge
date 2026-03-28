---
description: Create an ATTACKmd technique lookup note in the vault
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /attack <technique-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="30-Resources/ATTACK/TECHNIQUES/$NOTE_NAME.md" \
  template="ATTACKmd-Lookup" \
  open silent
