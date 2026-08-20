#!/usr/bin/env bash
# Check service statuses
for s in docker mpd wireplumber pipewire sshd beszel-agent; do
  echo "$s=$(systemctl --user is-active "$s" 2>/dev/null || systemctl is-active "$s" 2>/dev/null || echo inactive)"
done
