---
description: Create a container boundary research finding note
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /finding <finding-name>}"
obsidian create \
  name="$NOTE_NAME" \
  path="10-Projects/$NOTE_NAME.md" \
  template="Research-Finding" \
  open silent
