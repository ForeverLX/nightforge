---
description: Create a threat intel intake note
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /intel <intel-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="00-Inbox/$NOTE_NAME.md" \
  template="Threat-Intel" \
  open silent
