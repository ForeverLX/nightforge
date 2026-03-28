---
description: Create a tool documentation note
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /tool <tool-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="30-Resources/Security-Tools/$NOTE_NAME.md" \
  template="Tool-Note" \
  open silent
