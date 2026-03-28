---
description: Create a CVE intake note
---
#!/usr/bin/env bash
set -euo pipefail
NOTE_NAME="${1:?Usage: /cve <cve-id>}"
obsidian create \
  name="$NOTE_NAME" \
  path="00-Inbox/$NOTE_NAME.md" \
  template="CVE-Intake" \
  open silent
