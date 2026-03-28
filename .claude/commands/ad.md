---
description: Create an Active Directory technique note in the vault
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /ad <technique-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="30-Resources/Offensive-Security/$NOTE_NAME.md" \
  template="AD-Technique" \
  open silent
