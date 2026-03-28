---
description: Create a Cloud technique note in the vault
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /cloud <technique-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="30-Resources/Offensive-Security/$NOTE_NAME.md" \
  template="Cloud-Technique" \
  open silent
